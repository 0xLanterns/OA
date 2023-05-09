// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721} from "../../../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import {IAccessControl} from "../../../lib/openzeppelin-contracts/contracts//access/AccessControl.sol";

interface IEscher721 is IAccessControl, IERC721 {
    function initialize(address, address, string memory, string memory) external;

    function mint(address, uint256) external;

    function setDefaultUri(string memory) external;

    function resetDefaultRoyalty() external;

    function tokenURI(uint256) external view returns (string memory);
}