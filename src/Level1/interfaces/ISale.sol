// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISale {
    function buy(uint256) external payable;

    function getPrice() external view returns (uint256);

    function startTime() external view returns (uint256);

    function available() external view returns (uint256);

    function editionContract() external view returns (address);
}