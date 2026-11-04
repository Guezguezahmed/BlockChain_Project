// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*
 * SHARED INTERFACE v0.1
 * Both the contracts dev and the app dev build against this file.
 * If something changes, update this file first, then tell the other person.
 *
 * Design rules:
 *  - No owner, no admin, no pause, no upgradeability.
 *  - Funds can only move according to the rules below.
 *  - Amounts are in wei (ETH on Sepolia). Dates are unix timestamps (seconds).
 */

/// @notice Template types, so the app knows which UI to show for a contract.
enum TemplateType {
    Escrow,    // 0
    Rental,    // 1 (later)
    Milestone  // 2 (later)
}

/*//////////////////////////////////////////////////////////////
                            FACTORY
//////////////////////////////////////////////////////////////*/

interface IContractFactory {
    /// Emitted for EVERY contract created. The app and the indexer rely on this.
    event ContractCreated(
        address indexed creator,
        address indexed contractAddress,
        TemplateType indexed templateType,
        uint256 timestamp
    );

    /// Creates a new Escrow. The caller becomes the BUYER.
    /// Does not move money; the buyer calls fund() on the new contract after.
    function createEscrow(
        address seller,
        uint256 amount,    // wei the buyer must deposit
        uint256 deadline   // unix timestamp, must be in the future
    ) external returns (address escrow);

    /// Public registry (so contracts can be found even if the app is gone).
    function getAllContracts() external view returns (address[] memory);
    function getContractsByUser(address user) external view returns (address[] memory);
    function totalContracts() external view returns (uint256);
}

/*//////////////////////////////////////////////////////////////
                         ESCROW TEMPLATE
//////////////////////////////////////////////////////////////*/

interface IEscrow {
    enum State {
        Created,   // 0: deployed, waiting for the buyer's deposit
        Funded,    // 1: money locked in the contract
        Released,  // 2: money sent to seller (final)
        Refunded   // 3: money sent back to buyer (final)
    }

    // ---- Events (every state change emits one) ----
    event Funded(address indexed buyer, uint256 amount, uint256 timestamp);
    event Released(address indexed seller, uint256 amount, uint256 timestamp);
    event Refunded(address indexed buyer, uint256 amount, uint256 timestamp);

    // ---- Actions ----

    /// Buyer only. Must send exactly `amount` wei. State: Created -> Funded.
    function fund() external payable;

    /// Buyer only. Pays the seller. State: Funded -> Released.
    function release() external;

    /// Seller only, any time while Funded. Returns money to buyer.
    /// State: Funded -> Refunded.
    function refundBySeller() external;

    /// Buyer only, and only after `deadline` has passed while still Funded.
    /// State: Funded -> Refunded.
    function refundAfterDeadline() external;

    // ---- Reads (what the app screens need) ----
    function buyer() external view returns (address);
    function seller() external view returns (address);
    function amount() external view returns (uint256);
    function deadline() external view returns (uint256);
    function state() external view returns (State);
    function createdAt() external view returns (uint256);
}

/*
 * EXAMPLE FLOW (what the app does)
 * 1. Buyer fills the form -> app calls factory.createEscrow(seller, amount, deadline)
 * 2. Factory emits ContractCreated -> app reads the new address from the event
 * 3. Buyer taps "Deposit" -> app calls escrow.fund() with value = amount
 * 4. Goods/service delivered -> buyer taps "Release" -> escrow.release()
 *    OR seller taps "Refund" -> escrow.refundBySeller()
 *    OR deadline passes -> buyer taps "Reclaim" -> escrow.refundAfterDeadline()
 *
 * DECIDED: ETH only, no arbiter, no fee for v1.
 * KNOWN LIMITATION: after the deadline the buyer can always reclaim,
 * so the seller carries some risk (mention in the write-up).
 */

/*//////////////////////////////////////////////////////////////
                     SMART DEAL NFT MARKETPLACE
//////////////////////////////////////////////////////////////*/

/// @notice Primary MVP path: digital NFT sales with ETH payment + SDT fee/stake.
/// @dev Listings live in one Marketplace contract. On list, NFT is custodied here.
///      Buy transfers NFT to buyer and ETH to seller; cancel returns NFT + stake.
interface IMarketplace {
    struct Listing {
        address seller;
        address nft;
        uint256 tokenId;
        uint256 priceWei;
        uint256 stakeLocked;
        uint256 feePaid;
        bool active;
    }

    event ItemListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nft,
        uint256 tokenId,
        uint256 priceWei,
        uint256 feePaid,
        uint256 stakeLocked,
        uint256 timestamp
    );

    event ItemSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 priceWei,
        uint256 stakeReturned,
        uint256 timestamp
    );

    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller,
        uint256 stakeReturned,
        uint256 timestamp
    );

    /// Seller lists an NFT they own. Pulls SDT listing fee (burned) + stake (locked).
    /// NFT is transferred into the marketplace until buy or cancel.
    function listItem(
        address nft,
        uint256 tokenId,
        uint256 priceWei
    ) external returns (uint256 listingId);

    /// Buyer pays exact `priceWei` ETH. NFT goes to buyer; ETH to seller; stake unlocked.
    function buyItem(uint256 listingId) external payable;

    /// Seller cancels an active listing. NFT + stake returned. Fee stays burned.
    function cancelListing(uint256 listingId) external;

    function getListing(uint256 listingId) external view returns (Listing memory);
    function nextListingId() external view returns (uint256);
    function quoteListingFee(address seller) external view returns (uint256);
}
