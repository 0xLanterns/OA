// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Strings} from "../../../lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Base64} from "../../../lib/openzeppelin-contracts/contracts/utils/Base64.sol";
import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {ERC721} from "../../../lib/solmate/src/tokens/ERC721.sol";

import {PrivatePool} from "../PrivatePool.sol";

/// @title Private Pool Metadata
/// @author out.eth (@outdoteth)
/// @notice This contract is used to generate NFT metadata for private pools.
contract PrivatePoolMetadata {
    /// @notice Returns the tokenURI for a pool with it's metadata.
    /// @param tokenId The private pool's token ID.
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        // forgefmt: disable-next-item
        bytes memory metadata = abi.encodePacked(
            "{",
                '"name": "Private Pool ',Strings.toString(tokenId),'",',
                '"description": "Caviar private pool AMM position.",',
                '"image": ','"data:image/svg+xml;base64,', Base64.encode(svg(tokenId)),'",',
                '"attributes": [',
                    attributes(tokenId),
                "]",
            "}"
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(metadata)));
    }

    /// @notice Returns the attributes for a pool encoded as json.
    /// @param tokenId The private pool's token ID.
    function attributes(uint256 tokenId) public view returns (string memory) {
        PrivatePool privatePool = PrivatePool(payable(address(uint160(tokenId))));

        // forgefmt: disable-next-item
        bytes memory _attributes = abi.encodePacked(
            trait("Pool address", Strings.toHexString(address(privatePool))), ',',
            trait("Base token", Strings.toHexString(privatePool.baseToken())), ',',
            trait("NFT", Strings.toHexString(privatePool.nft())), ',',
            trait("Virtual base token reserves",Strings.toString(privatePool.virtualBaseTokenReserves())), ',',
            trait("Virtual NFT reserves", Strings.toString(privatePool.virtualNftReserves())), ',',
            trait("Fee rate (bps): ", Strings.toString(privatePool.feeRate())), ',',
            trait("NFT balance", Strings.toString(ERC721(privatePool.nft()).balanceOf(address(privatePool)))), ',',
            trait("Base token balance",  Strings.toString(privatePool.baseToken() == address(0) ? address(privatePool).balance : ERC20(privatePool.baseToken()).balanceOf(address(privatePool))))
        );

        return string(_attributes);
    }

    /// @notice Returns an svg image for a pool.
    /// @param tokenId The private pool's token ID.
    function svg(uint256 tokenId) public view returns (bytes memory) {
        PrivatePool privatePool = PrivatePool(payable(address(uint160(tokenId))));

        // break up svg building into multiple scopes to avoid stack too deep errors
        bytes memory _svg;
        {
            // forgefmt: disable-next-item
            _svg = abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" style="width:100%;background:black;fill:white;font-family:serif;">',
                    '<text x="24px" y="24px" font-size="12">',
                        "Caviar AMM private pool position",
                    "</text>",
                    '<text x="24px" y="48px" font-size="12">',
                        "Private pool: ", Strings.toHexString(address(privatePool)),
                    "</text>",
                    '<text x="24px" y="72px" font-size="12">',
                        "Base token: ", Strings.toHexString(privatePool.baseToken()),
                    "</text>",
                    '<text x="24px" y="96px" font-size="12">',
                        "NFT: ", Strings.toHexString(privatePool.nft()),
                    "</text>"
            );
        }

        {
            // forgefmt: disable-next-item
            _svg = abi.encodePacked(
                _svg,
                '<text x="24px" y="120px" font-size="12">',
                    "Virtual base token reserves: ", Strings.toString(privatePool.virtualBaseTokenReserves()),
                "</text>",
                '<text x="24px" y="144px" font-size="12">',
                    "Virtual NFT reserves: ", Strings.toString(privatePool.virtualNftReserves()),
                "</text>",
                '<text x="24px" y="168px" font-size="12">',
                    "Fee rate (bps): ", Strings.toString(privatePool.feeRate()),
                "</text>"
            );
        }

        {
            // forgefmt: disable-next-item
            _svg = abi.encodePacked(
                _svg, 
                    '<text x="24px" y="192px" font-size="12">',
                        "NFT balance: ", Strings.toString(ERC721(privatePool.nft()).balanceOf(address(privatePool))),
                    "</text>",
                    '<text x="24px" y="216px" font-size="12">',
                        "Base token balance: ", Strings.toString(privatePool.baseToken() == address(0) ? address(privatePool).balance : ERC20(privatePool.baseToken()).balanceOf(address(privatePool))),
                    "</text>",
                "</svg>"
            );
        }

        return _svg;
    }

    function trait(string memory traitType, string memory value) internal pure returns (string memory) {
        // forgefmt: disable-next-item
        return string(
            abi.encodePacked(
                '{ "trait_type": "', traitType, '",', '"value": "', value, '" }'
            )
        );
    }
}