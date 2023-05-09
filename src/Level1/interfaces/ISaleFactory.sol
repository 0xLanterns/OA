// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISaleFactory {
    function feeReceiver() external view returns (address payable);
}