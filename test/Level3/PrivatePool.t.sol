// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../lib/forge-std/src/Test.sol";
import "../../src/Level3/PrivatePool.sol";
import "../../lib/forge-std/src/console.sol";
import "../../src/Level3/context/Factory.sol";

import "../../Resources/ERC20s.sol";
import "../../lib/openzeppelin-contracts/contracts/token/common/ERC2981.sol";




contract TestPrivatePool is Test { 

    PrivatePool public privatePool;
    Factory public factory;
    address nft = address(new Milady());
    Token public token = new Token(); // You may change the token to one of the others from ERC20s.sol

    uint256[] inputTokenIds;
    uint256[] outputTokenIds;




    function setUp() public { 
        
privatePool = new PrivatePool(
            address(factory),
            address(0),
            address(0)
        );
        privatePool.initialize(
            address(token),
            nft,
            100e18,
            5e18,
            0,
            100,
            bytes32(0),
            false,
            false
        );
        for (uint256 i = 0; i < 3; i++) {
            Milady(nft).mint(address(this), i);
        }

        for (uint256 i = 3; i < 6; i++) {
            Milady(nft).mint(address(privatePool), i);
        }

        Milady(nft).setApprovalForAll(address(privatePool), true);
        Milady(nft).setApprovalForAll(address(privatePool), true);
        token.approve(address(privatePool), type(uint256).max);

        inputTokenIds.push(0);
        inputTokenIds.push(1);
        inputTokenIds.push(2);

        Milady(nft).mint(address(privatePool), 10);
        Milady(nft).mint(address(privatePool), 11);
        Milady(nft).mint(address(privatePool), 12);
        outputTokenIds.push(10);
        outputTokenIds.push(11);
        outputTokenIds.push(12);
        (uint256 feeAmount) = privatePool.changeFeeQuote(
           outputTokenIds.length * 1e18
        );
        deal(address(token), address(this), feeAmount);



    }

    // Run:  forge test --match-test testPOC3

    function testPOC3() public { 

        /**
        POC can go here 
         */
        vm.expectRevert();
        privatePool.change(
            inputTokenIds,
            outputTokenIds 
        );
    }


}








contract Milady is ERC721, ERC2981 {
    uint256 public royaltyFeeRate = 0; // to 18 decimals
    address public royaltyRecipient = address(0);

    constructor() ERC721("Milady Maker", "MIL") {}

    function tokenURI(uint256) public view virtual override returns (string memory) {
        return "https://milady.io";
    }

    function mint(address to, uint256 id) public {
        _mint(to, id);
    }

    function setRoyaltyInfo(uint256 _royaltyFeeRate, address _royaltyRecipient) public {
        royaltyFeeRate = _royaltyFeeRate;
        royaltyRecipient = _royaltyRecipient;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC2981, ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function royaltyInfo(uint256, uint256 salePrice) public view override returns (address, uint256) {
        return (address(0xbeefbeef), salePrice * royaltyFeeRate / 1e18);
    }
}