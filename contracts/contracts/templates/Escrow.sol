// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IEscrow} from "../interfaces/IContracts.sol";

/// @title Escrow
/// @notice ETH escrow template cloned by ContractFactory (EIP-1167).
/// @dev No owner/admin/pause/upgrade. Logic is immutable; each clone is initialized once.
contract Escrow is IEscrow, ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error AlreadyInitialized();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDeadline();
    error SellerEqualsBuyer();
    error NotBuyer();
    error NotSeller();
    error InvalidState();
    error IncorrectValue();
    error DeadlineNotPassed();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    bool private _initialized;

    address private _buyer;
    address private _seller;
    uint256 private _amount;
    uint256 private _deadline;
    uint256 private _createdAt;
    State private _state;

    /*//////////////////////////////////////////////////////////////
                             INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice One-time setup for a clone. Called by the factory in the same tx as creation.
    /// @param buyer_ Party that must deposit `amount_` wei.
    /// @param seller_ Party that receives funds on release.
    /// @param amount_ Exact wei the buyer must send in `fund()`.
    /// @param deadline_ Unix timestamp after which the buyer may reclaim while Funded.
    function initialize(
        address buyer_,
        address seller_,
        uint256 amount_,
        uint256 deadline_
    ) external {
        if (_initialized) revert AlreadyInitialized();
        if (buyer_ == address(0) || seller_ == address(0)) revert InvalidAddress();
        if (buyer_ == seller_) revert SellerEqualsBuyer();
        if (amount_ == 0) revert InvalidAmount();
        if (deadline_ <= block.timestamp) revert InvalidDeadline();

        _initialized = true;
        _buyer = buyer_;
        _seller = seller_;
        _amount = amount_;
        _deadline = deadline_;
        _createdAt = block.timestamp;
        _state = State.Created;
    }

    /*//////////////////////////////////////////////////////////////
                               ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IEscrow
    function fund() external payable nonReentrant {
        if (msg.sender != _buyer) revert NotBuyer();
        if (_state != State.Created) revert InvalidState();
        if (msg.value != _amount) revert IncorrectValue();

        _state = State.Funded;
        emit Funded(_buyer, _amount, block.timestamp);
    }

    /// @inheritdoc IEscrow
    function release() external nonReentrant {
        if (msg.sender != _buyer) revert NotBuyer();
        if (_state != State.Funded) revert InvalidState();

        _state = State.Released;
        emit Released(_seller, _amount, block.timestamp);

        (bool ok, ) = _seller.call{value: _amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @inheritdoc IEscrow
    function refundBySeller() external nonReentrant {
        if (msg.sender != _seller) revert NotSeller();
        if (_state != State.Funded) revert InvalidState();

        _state = State.Refunded;
        emit Refunded(_buyer, _amount, block.timestamp);

        (bool ok, ) = _buyer.call{value: _amount}("");
        if (!ok) revert TransferFailed();
    }

    /// @inheritdoc IEscrow
    function refundAfterDeadline() external nonReentrant {
        if (msg.sender != _buyer) revert NotBuyer();
        if (_state != State.Funded) revert InvalidState();
        if (block.timestamp < _deadline) revert DeadlineNotPassed();

        _state = State.Refunded;
        emit Refunded(_buyer, _amount, block.timestamp);

        (bool ok, ) = _buyer.call{value: _amount}("");
        if (!ok) revert TransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                                READS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IEscrow
    function buyer() external view returns (address) {
        return _buyer;
    }

    /// @inheritdoc IEscrow
    function seller() external view returns (address) {
        return _seller;
    }

    /// @inheritdoc IEscrow
    function amount() external view returns (uint256) {
        return _amount;
    }

    /// @inheritdoc IEscrow
    function deadline() external view returns (uint256) {
        return _deadline;
    }

    /// @inheritdoc IEscrow
    function state() external view returns (State) {
        return _state;
    }

    /// @inheritdoc IEscrow
    function createdAt() external view returns (uint256) {
        return _createdAt;
    }
}
