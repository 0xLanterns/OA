// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../../lib/forge-std/src/Test.sol";
import "../../src/Level0/ItsARace.sol";
import "../../Resources/ERC20s.sol";
import "../../lib/forge-std/src/console.sol";

contract TestRace is Test { 
    
    address constant zouvier = address(0x123);
    address constant kiki = address(0xabc);
    ItsARace public itsARace;
    Token cToken = new Token();
    Token lToken = new Token();

    function setUp() public {

        itsARace = new ItsARace(
            "first test",
            string(abi.encodePacked("Surge ", "first test", " Pool")),
            IERC20(address(cToken)),
            IERC20(address(lToken)),
            1e18, 
            0.8e18, 
            1e15, 
            1e15, 
            0.1e18, 
            0.4e18, 
            0.6e18);   

            lToken.mint(zouvier, 101e18);     

            vm.startPrank(zouvier);
            lToken.approve(address(itsARace), 101e18);

            itsARace.deposit(101e18);
            itsARace.approve(kiki, 60e18);  
            vm.stopPrank();


    }
// Run:  forge test --match-test testPOC0
    function testPOC0() public {
        vm.startPrank(kiki);
        /**
                poc can go here    
         */
        vm.stopPrank();

        
        vm.startPrank(zouvier);
        itsARace.approve(kiki, 40e18); // Zouvier wants to change kiki's allowance down to 40 pool tokens.
        vm.stopPrank();
        


        vm.startPrank(kiki);
        /**
                poc can go here
         */
        vm.stopPrank();

        validate();

    }


    function validate() internal {
        assertGt(itsARace.balanceOf(kiki), 60e18);   // assert kiki's balance is greater than what was originally approved. 
    }


}