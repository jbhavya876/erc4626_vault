// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IZKVerifier} from "./IZKVerifier.sol";

contract ProofOfReserves {
    IZKVerifier public immutable verifier;
    address public immutable vault;

    uint256 public lastVerifiedTimestamp;
    bytes32 public lastStateCommitment;

    error InvalidProof();
    error Unauthorized();

    event ReservesVerified(uint256 timestamp, bytes32 stateCommitment);

    constructor(address _verifier, address _vault) {
        verifier = IZKVerifier(_verifier);
        vault = _vault;
    }

    function submitProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[1] calldata input
    ) external {
        if (!verifier.verifyProof(a, b, c, input)) revert InvalidProof();

        lastVerifiedTimestamp = block.timestamp;
        lastStateCommitment = bytes32(input[0]);

        emit ReservesVerified(block.timestamp, lastStateCommitment);
    }

    function isSolvent() external view returns (bool) {
        if (lastVerifiedTimestamp == 0) return false;

        return block.timestamp <= lastVerifiedTimestamp + 24 hours;
    }
}
