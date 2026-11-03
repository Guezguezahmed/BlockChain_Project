// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEscrow} from "../interfaces/IContracts.sol";

/// @dev Test-only contract that tries to reenter Escrow on receiving ETH.
contract ReentrancyAttacker {
    IEscrow public escrow;
    enum AttackMode {
        None,
        Release,
        RefundBySeller,
        RefundAfterDeadline
    }

    AttackMode public mode;
    bool public attacked;

    receive() external payable {
        if (mode == AttackMode.None || attacked) {
            return;
        }
        attacked = true;
        if (mode == AttackMode.Release) {
            escrow.release();
        } else if (mode == AttackMode.RefundBySeller) {
            escrow.refundBySeller();
        } else if (mode == AttackMode.RefundAfterDeadline) {
            escrow.refundAfterDeadline();
        }
    }

    function setTarget(address escrow_) external {
        escrow = IEscrow(escrow_);
    }

    function setMode(AttackMode mode_) external {
        mode = mode_;
        attacked = false;
    }

    function fundEscrow() external payable {
        escrow.fund{value: msg.value}();
    }

    function callRelease() external {
        escrow.release();
    }

    function callRefundBySeller() external {
        escrow.refundBySeller();
    }

    function callRefundAfterDeadline() external {
        escrow.refundAfterDeadline();
    }
}
