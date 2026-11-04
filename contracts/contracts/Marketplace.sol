// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IMarketplace} from "./interfaces/IContracts.sol";

/// @title Marketplace
/// @notice Peer-to-peer NFT marketplace: buyers pay ETH; sellers pay SDT fee + stake.
/// @dev NFT custody pattern: on list, the NFT is transferred into this contract.
///      On buy it goes to the buyer; on cancel it returns to the seller.
///      Listing fees are burned. Stake is locked here and returned on sale or cancel.
///      No Ownable, no admin withdraw of ETH/NFTs/SDT.
contract Marketplace is IMarketplace, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Dead address used as burn sink (OZ ERC20 reverts on transfer to address(0)).
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress();
    error InvalidPrice();
    error NotNftOwner();
    error NotSeller();
    error ListingNotActive();
    error IncorrectPayment();
    error CannotBuyOwnListing();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public immutable sdt;
    uint256 public immutable listingFee; // SDT wei, full fee before discount
    uint256 public immutable sellerStake; // SDT wei locked while listed
    uint256 public immutable discountHoldThreshold; // SDT balance for 50% fee discount
    uint256 public immutable feeDiscountBps; // e.g. 5000 = 50% off

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 private _nextListingId = 1;
    mapping(uint256 => Listing) private _listings;
    /// @notice Aggregate SDT stake currently locked for a seller (across active listings).
    mapping(address => uint256) public lockedStake;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param sdt_ SDT token used for fees and stake.
    /// @param listingFee_ Full listing fee in SDT wei (e.g. 10e18).
    /// @param sellerStake_ Stake locked per listing in SDT wei (e.g. 50e18).
    /// @param discountHoldThreshold_ Balance threshold for fee discount (e.g. 100e18).
    /// @param feeDiscountBps_ Discount in basis points (5000 = 50%).
    constructor(
        address sdt_,
        uint256 listingFee_,
        uint256 sellerStake_,
        uint256 discountHoldThreshold_,
        uint256 feeDiscountBps_
    ) {
        if (sdt_ == address(0)) revert InvalidAddress();
        if (listingFee_ == 0 || sellerStake_ == 0) revert InvalidPrice();
        if (feeDiscountBps_ > 10_000) revert InvalidPrice();

        sdt = IERC20(sdt_);
        listingFee = listingFee_;
        sellerStake = sellerStake_;
        discountHoldThreshold = discountHoldThreshold_;
        feeDiscountBps = feeDiscountBps_;
    }

    /*//////////////////////////////////////////////////////////////
                               ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMarketplace
    function listItem(
        address nft,
        uint256 tokenId,
        uint256 priceWei
    ) external nonReentrant returns (uint256 listingId) {
        if (nft == address(0)) revert InvalidAddress();
        if (priceWei == 0) revert InvalidPrice();

        IERC721 nftContract = IERC721(nft);
        if (nftContract.ownerOf(tokenId) != msg.sender) revert NotNftOwner();

        uint256 fee = _listingFeeFor(msg.sender);
        uint256 totalSdt = fee + sellerStake;

        // Pull fee + stake in one transferFrom, then burn the fee portion.
        sdt.safeTransferFrom(msg.sender, address(this), totalSdt);
        if (fee > 0) {
            sdt.safeTransfer(BURN_ADDRESS, fee);
        }

        // Custody NFT in the marketplace until buy or cancel.
        nftContract.transferFrom(msg.sender, address(this), tokenId);

        listingId = _nextListingId;
        unchecked {
            _nextListingId = listingId + 1;
        }

        lockedStake[msg.sender] += sellerStake;

        _listings[listingId] = Listing({
            seller: msg.sender,
            nft: nft,
            tokenId: tokenId,
            priceWei: priceWei,
            stakeLocked: sellerStake,
            feePaid: fee,
            active: true
        });

        emit ItemListed(
            listingId,
            msg.sender,
            nft,
            tokenId,
            priceWei,
            fee,
            sellerStake,
            block.timestamp
        );
    }

    /// @inheritdoc IMarketplace
    function buyItem(uint256 listingId) external payable nonReentrant {
        Listing storage listing = _listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (msg.sender == listing.seller) revert CannotBuyOwnListing();
        if (msg.value != listing.priceWei) revert IncorrectPayment();

        listing.active = false;

        address seller = listing.seller;
        address nft = listing.nft;
        uint256 tokenId = listing.tokenId;
        uint256 priceWei = listing.priceWei;
        uint256 stake = listing.stakeLocked;

        lockedStake[seller] -= stake;

        // Effects done — interactions: NFT to buyer, ETH to seller, stake to seller.
        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);

        (bool ok, ) = seller.call{value: priceWei}("");
        if (!ok) revert TransferFailed();

        if (stake > 0) {
            sdt.safeTransfer(seller, stake);
        }

        emit ItemSold(listingId, msg.sender, seller, priceWei, stake, block.timestamp);
    }

    /// @inheritdoc IMarketplace
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = _listings[listingId];
        if (!listing.active) revert ListingNotActive();
        if (msg.sender != listing.seller) revert NotSeller();

        listing.active = false;

        address seller = listing.seller;
        address nft = listing.nft;
        uint256 tokenId = listing.tokenId;
        uint256 stake = listing.stakeLocked;

        lockedStake[seller] -= stake;

        IERC721(nft).transferFrom(address(this), seller, tokenId);

        if (stake > 0) {
            sdt.safeTransfer(seller, stake);
        }

        emit ListingCancelled(listingId, seller, stake, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMarketplace
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return _listings[listingId];
    }

    /// @inheritdoc IMarketplace
    function nextListingId() external view returns (uint256) {
        return _nextListingId;
    }

    /// @inheritdoc IMarketplace
    function quoteListingFee(address seller) external view returns (uint256) {
        return _listingFeeFor(seller);
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev 50% fee discount if seller already has stake locked OR holds ≥ threshold SDT.
    function _listingFeeFor(address seller) internal view returns (uint256) {
        bool discounted = lockedStake[seller] > 0 ||
            sdt.balanceOf(seller) >= discountHoldThreshold;
        if (!discounted || feeDiscountBps == 0) {
            return listingFee;
        }
        return listingFee - ((listingFee * feeDiscountBps) / 10_000);
    }
}
