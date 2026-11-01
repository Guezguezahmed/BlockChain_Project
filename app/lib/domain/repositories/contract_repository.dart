import '../models/escrow_contract.dart';
import '../models/transaction_result.dart';

/// Single data-access surface for screens (AGENTS.md §5).
///
/// Implementations:
/// - [MockContractRepository] — fake data for UI without chain
/// - [ChainContractRepository] — web3dart against Sepolia (source of truth)
/// - IndexedContractRepository — Phase 3 (not in this phase)
abstract class ContractRepository {
  /// Escrows where [userAddress] is buyer or seller (factory registry).
  Future<List<EscrowContract>> getContractsByUser(String userAddress);

  /// Public registry (used later by Explore; available for debugging).
  Future<List<EscrowContract>> getAllContracts();

  /// Fresh on-chain read — call before money-moving actions.
  Future<EscrowContract> getContract(String address);

  /// `factory.createEscrow` — connected wallet becomes the buyer.
  Future<TransactionResult> createEscrow(CreateEscrowParams params);

  /// Buyer deposits exact `amount` wei. Created → Funded.
  Future<TransactionResult> fund(String contractAddress);

  /// Buyer pays seller. Funded → Released.
  Future<TransactionResult> release(String contractAddress);

  /// Seller returns funds to buyer. Funded → Refunded.
  Future<TransactionResult> refundBySeller(String contractAddress);

  /// Buyer reclaim after deadline. Funded → Refunded.
  Future<TransactionResult> refundAfterDeadline(String contractAddress);
}
