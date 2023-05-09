// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../lib/forge-std/src/Test.sol";
import "../../src/Level1/TheBestThingsInLifeAreFree.sol";
import "../../lib/forge-std/src/console.sol";
import "../../Resources/ERC721s.sol";
import "../../lib/forge-std/src/console.sol";


contract TestBestThings is Test {
    address constant zouvier = address(0x123);
    address constant kiki = address(0xabc);
    BestThingsDutchAuction public bestThings;
    BestThingsDutchAuction.Sale public _sale;
    MyERC721 edition = new MyERC721("0xLantern","OA");


    function setUp() public {
            _sale = BestThingsDutchAuction.Sale({
            currentId: uint48(0),
            finalId: uint48(10),
            edition: address(edition),
            startPrice: uint80(uint256(1 ether)),
            finalPrice: uint80(uint256(0.1 ether)),
            dropPerSecond: uint80(uint256(0.1 ether) / 1 hours),
            startTime: uint96(block.timestamp),
            saleReceiver: payable(zouvier),
            endTime: uint96(block.timestamp + 100 days)
        });
        
        bestThings = new BestThingsDutchAuction();
        bestThings.initialize(_sale);
        vm.deal(kiki, 30_000 wei); 
    }

// Run:  forge test --match-test testPOC1

    function testPOC1() public {

        vm.startPrank(kiki);
        /**
                poc can go here
         */ 
        vm.stopPrank();

        validate();


    }


    function validate() internal {
     assertTrue(IEscher721(_sale.edition).ownerOf(1) == kiki); // Assert that you were able to buy the nft.
    }


}