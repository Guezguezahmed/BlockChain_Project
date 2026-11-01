// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IContractFactory, TemplateType} from "./interfaces/IContracts.sol";
import {Escrow} from "./templates/Escrow.sol";

/// @title ContractFactory
/// @notice Deploys Escrow clones (EIP-1167) and keeps a public registry. No owner/admin.
contract ContractFactory is IContractFactory {
    using Clones for address;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidImplementation();

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Immutable Escrow logic contract used as the EIP-1167 implementation.
    address public immutable escrowImplementation;

    address[] private _allContracts;
    mapping(address => address[]) private _contractsByUser;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param escrowImplementation_ Address of the deployed Escrow template logic.
    constructor(address escrowImplementation_) {
        if (escrowImplementation_ == address(0)) revert InvalidImplementation();
        escrowImplementation = escrowImplementation_;
    }

    /*//////////////////////////////////////////////////////////////
                               ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IContractFactory
    /// @dev Caller becomes the buyer. Money is not moved here; buyer calls fund() later.
    function createEscrow(
        address seller,
        uint256 amount,
        uint256 deadline
    ) external returns (address escrow) {
        escrow = escrowImplementation.clone();
        Escrow(escrow).initialize(msg.sender, seller, amount, deadline);

        _allContracts.push(escrow);
        _contractsByUser[msg.sender].push(escrow);
        // Seller also "uses" the contract; index so either party can find it later.
        if (seller != msg.sender) {
            _contractsByUser[seller].push(escrow);
        }

        emit ContractCreated(msg.sender, escrow, TemplateType.Escrow, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                               REGISTRY
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IContractFactory
    function getAllContracts() external view returns (address[] memory) {
        return _allContracts;
    }

    /// @inheritdoc IContractFactory
    function getContractsByUser(address user) external view returns (address[] memory) {
        return _contractsByUser[user];
    }

    /// @inheritdoc IContractFactory
    function totalContracts() external view returns (uint256) {
        return _allContracts.length;
    }
}
