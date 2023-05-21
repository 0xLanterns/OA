// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStolenNftOracle {
    // copied from https://github.com/reservoirprotocol/oracle/blob/main/contracts/ReservoirOracle.sol
    struct Message {
        bytes32 id;
        bytes payload;
        // The UNIX timestamp when the message was signed by the oracle
        uint256 timestamp;
        // ECDSA signature or EIP-2098 compact signature
        bytes signature;
    }

    /// @notice Validates that a set of token ids have not been marked as stolen by the oracle.
    /// @dev Check a signed message from the oracle to ensure that the token ids have not been marked as stolen.
    /// @param tokenAddress The address of the token contract.
    /// @param tokenIds The token ids to validate.
    /// @param proofs The proofs that the token ids have not been marked as stolen.
    function validateTokensAreNotStolen(address tokenAddress, uint256[] calldata tokenIds, Message[] calldata proofs)
        external;
}