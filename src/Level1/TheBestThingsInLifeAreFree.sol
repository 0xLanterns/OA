// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISale} from "./interfaces/ISale.sol";
import {ISaleFactory} from "./interfaces/ISaleFactory.sol";
import {IEscher721} from "./interfaces/IEscher721.sol";
import {Initializable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract BestThingsDutchAuction is Initializable, OwnableUpgradeable, ISale {
    address public immutable factory;
    /// we use different uints and some weird ordering to pack variables into 32 bytes
    struct Sale {
        // slot 1
        uint48 currentId;
        uint48 finalId;
        address edition;
        // slot 2
        uint80 startPrice;
        uint80 finalPrice;
        uint80 dropPerSecond;
        // slot 3
        uint96 endTime;
        address payable saleReceiver;
        // slot 4
        uint96 startTime;
    }

    struct Receipt {
        uint48 amount;
        uint80 balance;
    }

    /// @notice sale info for this fixed price edition
    Sale public sale;
    uint48 public amountSold = 0;

    /// @notice tracked the amount paid by people during the LPDA
    mapping(address => Receipt) public receipts;

    event Start(Sale _saleInfo);
    event End(Sale _saleInfo);
    event Buy(address indexed _buyer, uint256 _amount, uint256 _value, Sale _saleInfo);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        factory = msg.sender;
        uint48 x = type(uint48).max;
        uint80 y = type(uint80).max;
        uint96 z = type(uint96).max;
        address payable i = payable(address(0));
        sale = BestThingsDutchAuction.Sale(x, x, i, y, y, y, z, i, z);
    }

    /// @notice buy from a fixed price sale after the sale starts
    /// @param _amount the amount of editions to buy
    function buy(uint256 _amount) external payable {
        uint48 amount = uint48(_amount);
        Sale memory temp = sale;
        IEscher721 nft = IEscher721(temp.edition);
        require(block.timestamp >= temp.startTime, "TOO SOON");
        uint256 price = getPrice();
        require(msg.value >= amount * price, "WRONG PRICE");
        
        amountSold += amount;
        uint48 newId = amount + temp.currentId;
        require(newId <= temp.finalId, "TOO MANY");

        receipts[msg.sender].amount += amount;
        receipts[msg.sender].balance += uint80(msg.value);

        for (uint256 x = temp.currentId + 1; x <= newId; x++) {
            nft.mint(msg.sender, x);
        }

        sale.currentId = newId;

        emit Buy(msg.sender, amount, msg.value, temp);

        if (newId == temp.finalId) {
            sale.finalPrice = uint80(price);
            uint256 totalSale = price * amountSold;
       
            temp.saleReceiver.transfer(totalSale);
            _end();
        }
    }

    /// @notice cancel a fixed price sale
    function cancel() external onlyOwner {
        require(block.timestamp < sale.startTime, "TOO LATE");
        sale.finalId = sale.currentId;
        _end();
    }

    /// @notice allow a buyer to get a refund on the current price difference
    function refund() public {
        Receipt memory r = receipts[msg.sender];
        uint80 price = uint80(getPrice()) * r.amount;
        uint80 owed = r.balance - price;
        require(owed > 0, "NOTHING TO REFUND");
        receipts[msg.sender].balance = price;
        payable(msg.sender).transfer(owed);
    }

    /// @notice initialize the proxy sale contract
    /// @param _sale the sale info
    function initialize(Sale calldata _sale) public initializer {
        sale = _sale;
        _transferOwnership(sale.saleReceiver);
        emit Start(_sale);
    }

    /// @notice the price of the sale
    function getPrice() public view returns (uint256) {
        Sale memory temp = sale; // 1 eth 
        (uint256 start, uint256 end) = (temp.startTime, temp.endTime);
        if (block.timestamp < start) return type(uint256).max;
        if (temp.currentId == temp.finalId) return temp.finalPrice;

        uint256 timeElapsed = end > block.timestamp ? block.timestamp - start : end - start;
        return temp.startPrice - (temp.dropPerSecond * timeElapsed);
    }

    /// @notice the start time of the sale
    function startTime() public view returns (uint256) {
        return sale.startTime;
    }

    /// @notice the edition contract having the sale
    function editionContract() public view returns (address) {
        return sale.edition;
    }

    /// @notice the number of NFTs still available
    function available() public view returns (uint256) {
        return sale.finalId - sale.currentId;
    }

    function lowestPrice() public view returns (uint256) {
        return sale.startPrice - (sale.dropPerSecond * (sale.endTime - sale.startTime));
    }

    function _end() internal {
        emit End(sale);
    }
}