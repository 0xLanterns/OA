// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../lib/solmate/src/tokens/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("Lantern Coin", "OA", 18) {}

   function mint(address account, uint256 amount) external {
        _mint(account, amount);
   }

   function _mint(address account, uint256 amount) internal override {
        super._mint(account,amount);
    }
}

contract GUSD is ERC20 {
    constructor() ERC20("Gemini USD", "gUSD", 2) {}
}

contract TUSD is ERC20 {
    uint immutable fee;

    constructor() ERC20("Tether USD", "tUSD", 18) {
        fee = 1;
    }

    // --- Token ---
    function transferFrom(
        address src,
        address dst,
        uint wad
    ) public override returns (bool) {
        require(balanceOf[src] >= wad, "insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != type(uint).max) {
            require(
                allowance[src][msg.sender] >= wad,
                "insufficient-allowance"
            );
            allowance[src][msg.sender] = (allowance[src][msg.sender] - wad);
        }

        balanceOf[src] = (balanceOf[src] - wad);
        balanceOf[dst] = balanceOf[dst] + (wad - fee);
        balanceOf[address(0)] = (balanceOf[address(0)] + fee);

        return true;
    }

    function transfer(address dst, uint wad) public override returns (bool) {
        balanceOf[msg.sender] = (balanceOf[msg.sender] - wad);
        balanceOf[dst] = balanceOf[dst] + (wad - fee);
        balanceOf[address(0)] = (balanceOf[address(0)] + fee);

        return true;
    }
}

contract LEND is ERC20 {
    mapping(address => uint256) balances;

    constructor() ERC20("LEND", "lend", 18) {}

    function transferFrom(
        address src,
        address dst,
        uint wad
    ) public override returns (bool) {
        require(balances[dst] + wad > balances[dst]);
        return super.transferFrom(src, dst, wad);
    }

    function transfer(address dst, uint wad) public override returns (bool) {
        require(balances[dst] + wad > balances[dst]);
        return super.transfer(dst, wad);
    }
}