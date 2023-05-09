// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../lib/forge-std/src/Test.sol";
import "../../src/Level2/LenderAlwaysWins.sol";
import "../../lib/forge-std/src/console.sol";


contract TestLenderWins is Test { 

    address constant zouvier = address(0x123);
    address constant kiki = address(0xabc);
    LenderAlwaysWins public lenderAlwaysWins;
    ERC20 cToken = new ERC20("0xLanternToken","OA"); // = $1000 usd
    ERC20 dToken = new ERC20("dai","dai");


    uint256 public duration = 1 days;
    uint256 public interest = 0;
    uint256 public loanToCollateral = 1e20;

    uint time = 100_000;
    uint256 public reqId;
    uint256 public loanId;

    function setUp() public { // Requesting 1k dai and im putting up  10 oa (10k usd)
        
        lenderAlwaysWins = new LenderAlwaysWins(zouvier,cToken,dToken);
        
        cToken.mint(zouvier,100e18);

        vm.startPrank(zouvier);
        cToken.approve(address(lenderAlwaysWins), 10e18);
        reqId = lenderAlwaysWins.request(1_000e18, interest, loanToCollateral, duration); 
        vm.stopPrank();

        dToken.mint(kiki,2_000e18);

        vm.startPrank(kiki);
        dToken.approve(address(lenderAlwaysWins), 1_000e18);
        loanId = lenderAlwaysWins.clear(reqId);
        vm.stopPrank();

        vm.warp(86399); 


    }

    // Run:  forge test --match-test testPOC2

    function testPOC2() public { 
        vm.startPrank(kiki);
        /**
                poc can go here
         */
        vm.stopPrank();


        vm.startPrank(zouvier);
        dToken.approve(address(lenderAlwaysWins), 1_000e18);
        vm.expectRevert();
        lenderAlwaysWins.repay(loanId, 1_000e18); // Zouvier is going to make a last second payment and pay the loan back in full.
        vm.stopPrank();


        vm.startPrank(kiki);
        /**
                poc can go here
         */
        vm.stopPrank();



        validate();

    }


    function validate() internal {
        skip(3);

        lenderAlwaysWins.defaulted(loanId);
        assertEq(cToken.balanceOf(kiki), 10e18);
    }


}