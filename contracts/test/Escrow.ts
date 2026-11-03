import { expect } from "chai";
import { ethers } from "hardhat";
import {
  loadFixture,
  time,
} from "@nomicfoundation/hardhat-network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ContractFactory, Escrow, ReentrancyAttacker } from "../typechain-types";

const ONE_ETH = ethers.parseEther("1");
const TemplateTypeEscrow = 0n;
const State = {
  Created: 0n,
  Funded: 1n,
  Released: 2n,
  Refunded: 3n,
} as const;

async function deployFixture() {
  const [deployer, buyer, seller, stranger] = await ethers.getSigners();

  const EscrowFactory = await ethers.getContractFactory("Escrow");
  const escrowImpl = (await EscrowFactory.deploy()) as unknown as Escrow;
  await escrowImpl.waitForDeployment();

  const Factory = await ethers.getContractFactory("ContractFactory");
  const factory = (await Factory.deploy(
    await escrowImpl.getAddress()
  )) as unknown as ContractFactory;
  await factory.waitForDeployment();

  const Attacker = await ethers.getContractFactory("ReentrancyAttacker");
  const attacker = (await Attacker.deploy()) as unknown as ReentrancyAttacker;
  await attacker.waitForDeployment();

  return { deployer, buyer, seller, stranger, escrowImpl, factory, attacker };
}

async function createEscrow(
  factory: ContractFactory,
  buyer: HardhatEthersSigner,
  seller: string,
  amount: bigint,
  deadlineOffsetSeconds = 7 * 24 * 60 * 60
) {
  const deadline = (await time.latest()) + deadlineOffsetSeconds;
  const tx = await factory.connect(buyer).createEscrow(seller, amount, deadline);
  const receipt = await tx.wait();
  const created = receipt?.logs
    .map((log) => {
      try {
        return factory.interface.parseLog({
          topics: [...log.topics],
          data: log.data,
        });
      } catch {
        return null;
      }
    })
    .find((parsed) => parsed?.name === "ContractCreated");

  if (!created) {
    throw new Error("ContractCreated event not found");
  }

  const escrowAddress = created.args.contractAddress as string;
  const escrow = (await ethers.getContractAt(
    "Escrow",
    escrowAddress
  )) as unknown as Escrow;

  return { escrow, escrowAddress, deadline, tx, receipt, created };
}

describe("Escrow", () => {
  describe("initialize (via factory)", () => {
    it("sets buyer, seller, amount, deadline, Created state, createdAt", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const before = await time.latest();
      const { escrow, deadline } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH
      );
      const after = await time.latest();

      expect(await escrow.buyer()).to.equal(buyer.address);
      expect(await escrow.seller()).to.equal(seller.address);
      expect(await escrow.amount()).to.equal(ONE_ETH);
      expect(await escrow.deadline()).to.equal(deadline);
      expect(await escrow.state()).to.equal(State.Created);
      const createdAt = await escrow.createdAt();
      expect(createdAt).to.be.gte(before);
      expect(createdAt).to.be.lte(after);
    });

    it("reverts when initialize is called twice on a clone", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH
      );

      await expect(
        escrow.initialize(buyer.address, seller.address, ONE_ETH, (await time.latest()) + 1000)
      ).to.be.revertedWithCustomError(escrow, "AlreadyInitialized");
    });

    it("reverts on zero seller", async () => {
      const { buyer, factory } = await loadFixture(deployFixture);
      const deadline = (await time.latest()) + 1000;
      await expect(
        factory.connect(buyer).createEscrow(ethers.ZeroAddress, ONE_ETH, deadline)
      ).to.be.revertedWithCustomError(
        await ethers.getContractFactory("Escrow"),
        "InvalidAddress"
      );
    });

    it("reverts when seller equals buyer", async () => {
      const { buyer, factory } = await loadFixture(deployFixture);
      const deadline = (await time.latest()) + 1000;
      await expect(
        factory.connect(buyer).createEscrow(buyer.address, ONE_ETH, deadline)
      ).to.be.revertedWithCustomError(
        await ethers.getContractFactory("Escrow"),
        "SellerEqualsBuyer"
      );
    });

    it("reverts on zero amount", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const deadline = (await time.latest()) + 1000;
      await expect(
        factory.connect(buyer).createEscrow(seller.address, 0, deadline)
      ).to.be.revertedWithCustomError(
        await ethers.getContractFactory("Escrow"),
        "InvalidAmount"
      );
    });

    it("reverts when deadline is not in the future", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const now = await time.latest();
      await expect(
        factory.connect(buyer).createEscrow(seller.address, ONE_ETH, now)
      ).to.be.revertedWithCustomError(
        await ethers.getContractFactory("Escrow"),
        "InvalidDeadline"
      );
    });
  });

  describe("fund", () => {
    it("happy path: Created -> Funded, emits Funded, locks ETH", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow, escrowAddress } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH
      );

      const tx = await escrow.connect(buyer).fund({ value: ONE_ETH });
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt!.blockNumber);
      await expect(tx)
        .to.emit(escrow, "Funded")
        .withArgs(buyer.address, ONE_ETH, block!.timestamp);

      expect(await escrow.state()).to.equal(State.Funded);
      expect(await ethers.provider.getBalance(escrowAddress)).to.equal(ONE_ETH);
    });

    it("reverts if caller is not buyer", async () => {
      const { buyer, seller, stranger, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await expect(
        escrow.connect(stranger).fund({ value: ONE_ETH })
      ).to.be.revertedWithCustomError(escrow, "NotBuyer");
    });

    it("reverts if value is not exact amount", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await expect(
        escrow.connect(buyer).fund({ value: ethers.parseEther("0.5") })
      ).to.be.revertedWithCustomError(escrow, "IncorrectValue");
    });

    it("reverts if already funded", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await expect(
        escrow.connect(buyer).fund({ value: ONE_ETH })
      ).to.be.revertedWithCustomError(escrow, "InvalidState");
    });
  });

  describe("release", () => {
    it("happy path: Funded -> Released, pays seller, emits Released", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow, escrowAddress } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH
      );
      await escrow.connect(buyer).fund({ value: ONE_ETH });

      const sellerBefore = await ethers.provider.getBalance(seller.address);
      const tx = await escrow.connect(buyer).release();
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt!.blockNumber);

      await expect(tx)
        .to.emit(escrow, "Released")
        .withArgs(seller.address, ONE_ETH, block!.timestamp);

      expect(await escrow.state()).to.equal(State.Released);
      expect(await ethers.provider.getBalance(escrowAddress)).to.equal(0n);
      expect(await ethers.provider.getBalance(seller.address)).to.equal(
        sellerBefore + ONE_ETH
      );
    });

    it("reverts if caller is not buyer", async () => {
      const { buyer, seller, stranger, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await expect(
        escrow.connect(stranger).release()
      ).to.be.revertedWithCustomError(escrow, "NotBuyer");
    });

    it("reverts if not Funded", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await expect(escrow.connect(buyer).release()).to.be.revertedWithCustomError(
        escrow,
        "InvalidState"
      );
    });

    it("reverts on double release", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await escrow.connect(buyer).release();
      await expect(escrow.connect(buyer).release()).to.be.revertedWithCustomError(
        escrow,
        "InvalidState"
      );
    });
  });

  describe("refundBySeller", () => {
    it("happy path: Funded -> Refunded, pays buyer, emits Refunded", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow, escrowAddress } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH
      );
      await escrow.connect(buyer).fund({ value: ONE_ETH });

      const buyerBefore = await ethers.provider.getBalance(buyer.address);
      const tx = await escrow.connect(seller).refundBySeller();
      const receipt = await tx.wait();
      const block = await ethers.provider.getBlock(receipt!.blockNumber);

      await expect(tx)
        .to.emit(escrow, "Refunded")
        .withArgs(buyer.address, ONE_ETH, block!.timestamp);

      expect(await escrow.state()).to.equal(State.Refunded);
      expect(await ethers.provider.getBalance(escrowAddress)).to.equal(0n);
      expect(await ethers.provider.getBalance(buyer.address)).to.equal(
        buyerBefore + ONE_ETH
      );
    });

    it("reverts if caller is not seller", async () => {
      const { buyer, seller, stranger, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await expect(
        escrow.connect(stranger).refundBySeller()
      ).to.be.revertedWithCustomError(escrow, "NotSeller");
    });

    it("reverts if not Funded", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await expect(
        escrow.connect(seller).refundBySeller()
      ).to.be.revertedWithCustomError(escrow, "InvalidState");
    });
  });

  describe("refundAfterDeadline", () => {
    it("happy path after deadline: Funded -> Refunded", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow, escrowAddress, deadline } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH,
        1000
      );
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await time.increaseTo(deadline);

      const buyerBefore = await ethers.provider.getBalance(buyer.address);
      const tx = await escrow.connect(buyer).refundAfterDeadline();
      const receipt = await tx.wait();
      const gas = receipt!.gasUsed * receipt!.gasPrice;
      const block = await ethers.provider.getBlock(receipt!.blockNumber);

      await expect(tx)
        .to.emit(escrow, "Refunded")
        .withArgs(buyer.address, ONE_ETH, block!.timestamp);

      expect(await escrow.state()).to.equal(State.Refunded);
      expect(await ethers.provider.getBalance(escrowAddress)).to.equal(0n);
      expect(await ethers.provider.getBalance(buyer.address)).to.equal(
        buyerBefore + ONE_ETH - gas
      );
    });

    it("reverts before deadline", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH,
        10_000
      );
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await expect(
        escrow.connect(buyer).refundAfterDeadline()
      ).to.be.revertedWithCustomError(escrow, "DeadlineNotPassed");
    });

    it("reverts if caller is not buyer", async () => {
      const { buyer, seller, stranger, factory } = await loadFixture(deployFixture);
      const { escrow, deadline } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH,
        1000
      );
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await time.increaseTo(deadline);
      await expect(
        escrow.connect(stranger).refundAfterDeadline()
      ).to.be.revertedWithCustomError(escrow, "NotBuyer");
    });

    it("reverts if not Funded", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow, deadline } = await createEscrow(
        factory,
        buyer,
        seller.address,
        ONE_ETH,
        1000
      );
      await time.increaseTo(deadline);
      await expect(
        escrow.connect(buyer).refundAfterDeadline()
      ).to.be.revertedWithCustomError(escrow, "InvalidState");
    });
  });

  describe("reentrancy", () => {
    it("blocks reentrancy on release when seller is malicious", async () => {
      const { buyer, factory, attacker } = await loadFixture(deployFixture);
      const attackerAddress = await attacker.getAddress();
      const { escrow } = await createEscrow(
        factory,
        buyer,
        attackerAddress,
        ONE_ETH
      );
      await attacker.setTarget(await escrow.getAddress());
      // AttackMode.Release = 1
      await attacker.setMode(1);
      await escrow.connect(buyer).fund({ value: ONE_ETH });

      await expect(escrow.connect(buyer).release()).to.be.revertedWithCustomError(
        escrow,
        "TransferFailed"
      );
      expect(await escrow.state()).to.equal(State.Funded);
      expect(await ethers.provider.getBalance(await escrow.getAddress())).to.equal(
        ONE_ETH
      );
    });

    it("blocks reentrancy on refundBySeller when buyer is malicious", async () => {
      const { seller, factory, attacker } = await loadFixture(deployFixture);
      const attackerAddress = await attacker.getAddress();
      // Attacker is buyer (creator)
      const deadline = (await time.latest()) + 10_000;
      const tx = await factory
        .connect(await ethers.getSigner(attackerAddress))
        .createEscrow(seller.address, ONE_ETH, deadline)
        .catch(() => null);

      // Attacker contract cannot call factory easily without a helper — fund via
      // creating escrow with attacker as buyer using an EOA that transfers role...
      // Instead: create with attacker as buyer by having attacker create through a
      // temporary approach — deploy a clone manually is out of scope.
      // Use factory from a signer, then we need attacker as buyer.
      // ReentrancyAttacker can create if we add a create helper; simpler path:
      // create escrow where buyer is attacker by impersonating? Use connect with
      // a funded wallet that IS the attacker — can't, attacker is a contract.
      // Solution: have the factory create with buyer=EOA, but for refundBySeller
      // the ETH goes to buyer. So buyer must be the attacker contract.
      // Add createEscrow helper on attacker OR use Hardhat impersonation after
      // giving the attacker ETH and having a create function.

      void tx;
      const CreateHelper = attacker;
      // Use hardhat to send a createEscrow from attacker via low-level call after
      // giving it ETH and a factory-create wrapper — add method below in a second
      // compile if needed. For now create via factory with buyer as attacker using
      // ethers hardhat_impersonateAccount.
      await ethers.provider.send("hardhat_setBalance", [
        attackerAddress,
        "0x56BC75E2D63100000", // 100 ETH
      ]);
      await ethers.provider.send("hardhat_impersonateAccount", [attackerAddress]);
      const attackerSigner = await ethers.getSigner(attackerAddress);
      const createTx = await factory
        .connect(attackerSigner)
        .createEscrow(seller.address, ONE_ETH, (await time.latest()) + 10_000);
      const createReceipt = await createTx.wait();
      const created = createReceipt!.logs
        .map((log) => {
          try {
            return factory.interface.parseLog({
              topics: [...log.topics],
              data: log.data,
            });
          } catch {
            return null;
          }
        })
        .find((p) => p?.name === "ContractCreated");
      const escrowAddress = created!.args.contractAddress as string;
      const escrow = (await ethers.getContractAt(
        "Escrow",
        escrowAddress
      )) as unknown as Escrow;

      await attacker.setTarget(escrowAddress);
      // AttackMode.RefundBySeller = 2
      await attacker.setMode(2);
      await attacker.fundEscrow({ value: ONE_ETH });

      await expect(
        escrow.connect(seller).refundBySeller()
      ).to.be.revertedWithCustomError(escrow, "TransferFailed");
      expect(await escrow.state()).to.equal(State.Funded);
      expect(await ethers.provider.getBalance(escrowAddress)).to.equal(ONE_ETH);

      await ethers.provider.send("hardhat_stopImpersonatingAccount", [
        attackerAddress,
      ]);
      void CreateHelper;
    });
  });

  describe("terminal state exclusivity", () => {
    it("cannot refund after release", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await escrow.connect(buyer).release();
      await expect(
        escrow.connect(seller).refundBySeller()
      ).to.be.revertedWithCustomError(escrow, "InvalidState");
    });

    it("cannot release after refund", async () => {
      const { buyer, seller, factory } = await loadFixture(deployFixture);
      const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
      await escrow.connect(buyer).fund({ value: ONE_ETH });
      await escrow.connect(seller).refundBySeller();
      await expect(escrow.connect(buyer).release()).to.be.revertedWithCustomError(
        escrow,
        "InvalidState"
      );
    });
  });
});

describe("ContractFactory", () => {
  it("emits ContractCreated with Escrow template type", async () => {
    const { buyer, seller, factory } = await loadFixture(deployFixture);
    const deadline = (await time.latest()) + 1000;
    const tx = await factory
      .connect(buyer)
      .createEscrow(seller.address, ONE_ETH, deadline);
    const receipt = await tx.wait();
    const block = await ethers.provider.getBlock(receipt!.blockNumber);

    await expect(tx)
      .to.emit(factory, "ContractCreated")
      .withArgs(
        buyer.address,
        await (async () => {
          const parsed = receipt!.logs
            .map((log) => {
              try {
                return factory.interface.parseLog({
                  topics: [...log.topics],
                  data: log.data,
                });
              } catch {
                return null;
              }
            })
            .find((p) => p?.name === "ContractCreated");
          return parsed!.args.contractAddress;
        })(),
        TemplateTypeEscrow,
        block!.timestamp
      );
  });

  it("tracks registry: totalContracts, getAllContracts, getContractsByUser", async () => {
    const { buyer, seller, stranger, factory } = await loadFixture(deployFixture);

    expect(await factory.totalContracts()).to.equal(0n);
    expect(await factory.getAllContracts()).to.deep.equal([]);

    const a = await createEscrow(factory, buyer, seller.address, ONE_ETH);
    const b = await createEscrow(
      factory,
      buyer,
      stranger.address,
      ethers.parseEther("2")
    );

    expect(await factory.totalContracts()).to.equal(2n);
    expect(await factory.getAllContracts()).to.deep.equal([
      a.escrowAddress,
      b.escrowAddress,
    ]);
    expect(await factory.getContractsByUser(buyer.address)).to.deep.equal([
      a.escrowAddress,
      b.escrowAddress,
    ]);
    expect(await factory.getContractsByUser(seller.address)).to.deep.equal([
      a.escrowAddress,
    ]);
    expect(await factory.getContractsByUser(stranger.address)).to.deep.equal([
      b.escrowAddress,
    ]);
  });

  it("clone is independent from implementation storage", async () => {
    const { buyer, seller, factory, escrowImpl } = await loadFixture(deployFixture);
    const { escrow } = await createEscrow(factory, buyer, seller.address, ONE_ETH);
    expect(await escrowImpl.buyer()).to.equal(ethers.ZeroAddress);
    expect(await escrow.buyer()).to.equal(buyer.address);
  });

  it("stores escrowImplementation immutably", async () => {
    const { factory, escrowImpl } = await loadFixture(deployFixture);
    expect(await factory.escrowImplementation()).to.equal(
      await escrowImpl.getAddress()
    );
  });

  it("constructor reverts on zero implementation", async () => {
    const Factory = await ethers.getContractFactory("ContractFactory");
    await expect(Factory.deploy(ethers.ZeroAddress)).to.be.revertedWithCustomError(
      Factory,
      "InvalidImplementation"
    );
  });
});
