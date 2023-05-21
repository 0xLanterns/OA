// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
 *
 *       __________...----..____..-'``-..___
 *     ,'.                                  ```--.._
 *    :                                             ``._
 *    |                           --                    ``.
 *    |                 -0-           -.     -   -.        `.
 *    :                     __           --            .     \
 *     `._____________     (  `.   -.-      --  -   .   `     \
 *        `-----------------\   \_.--------..__..--.._ `. `.   :
 *                           `--'                     `-._ .   |
 *                                                        `.`  |
 *                                                          \` |
 *                                                           \ |
 *                                                           / \`.
 *                                                          /  _\-'
 *                                                         /_,'
 */

import {LibClone} from "../../../lib/solady/src/utils/LibClone.sol";
import {ERC20} from "../../../lib/solmate/src/tokens/ERC20.sol";
import {ERC721} from "../../../lib/solmate/src/tokens/ERC721.sol";
import {Owned} from "../../../lib/solmate/src/auth/Owned.sol";
import {SafeTransferLib} from "../../../lib/solmate/src/utils/SafeTransferLib.sol";

import {PrivatePool} from "../PrivatePool.sol";
import {PrivatePoolMetadata} from "./PrivatePoolMetadata.sol";

/// @title Caviar Private Pool Factory
/// @author out.eth (@outdoteth)
/// @notice This contract is used to create and initialize new private pools. Each time a private pool is created, a new
/// NFT representing that private pool is minted to the creator. All protocol fees also accrue to this contract and can
/// be withdrawn by the admin.
contract Factory is ERC721, Owned {
    using LibClone for address;
    using SafeTransferLib for address;

    event Create(address indexed privatePool, uint256[] tokenIds, uint256 baseTokenAmount);
    event Withdraw(address indexed token, uint256 indexed amount);

    /// @notice The address of the private pool implementation that proxies point to.
    address public privatePoolImplementation;

    /// @notice Helper contract that constructs the private pool metadata svg and json for each pool NFT.
    address public privatePoolMetadata;

    /// @notice The protocol fee that is taken on each buy/sell/change. It's in basis points: 350 = 3.5%.
    uint16 public protocolFeeRate;

    constructor() ERC721("Caviar Private Pools", "POOL") Owned(msg.sender) {}

    receive() external payable {}

    /// @notice Creates a new private pool using the minimal proxy pattern that points to the private pool
    /// implementation. The caller must approve the factory to transfer the NFTs that will be deposited to the pool.
    /// @param _baseToken The address of the base token.
    /// @param _nft The address of the NFT.
    /// @param _virtualBaseTokenReserves The virtual base token reserves.
    /// @param _virtualNftReserves The virtual NFT reserves.
    /// @param _changeFee The change fee.
    /// @param _feeRate The fee rate.
    /// @param _merkleRoot The merkle root.
    /// @param _useStolenNftOracle Whether to use the stolen NFT oracle.
    /// @param _salt The salt that will used on deployment.
    /// @param tokenIds The token ids to deposit to the pool.
    /// @param baseTokenAmount The amount of base tokens to deposit to the pool.
    /// @return privatePool The address of the private pool.
    function create(
        address _baseToken,
        address _nft,
        uint128 _virtualBaseTokenReserves,
        uint128 _virtualNftReserves,
        uint56 _changeFee,
        uint16 _feeRate,
        bytes32 _merkleRoot,
        bool _useStolenNftOracle,
        bool _payRoyalties,
        bytes32 _salt,
        uint256[] memory tokenIds, // put in memory to avoid stack too deep error
        uint256 baseTokenAmount
    ) public payable returns (PrivatePool privatePool) {
        // check that the msg.value is equal to the base token amount if the base token is ETH or the msg.value is equal
        // to zero if the base token is not ETH
        if ((_baseToken == address(0) && msg.value != baseTokenAmount) || (_baseToken != address(0) && msg.value > 0)) {
            revert PrivatePool.InvalidEthAmount();
        }

        // deploy a minimal proxy clone of the private pool implementation
        privatePool = PrivatePool(payable(privatePoolImplementation.cloneDeterministic(_salt)));

        // mint the nft to the caller
        _safeMint(msg.sender, uint256(uint160(address(privatePool))));

        // initialize the pool
        privatePool.initialize(
            _baseToken,
            _nft,
            _virtualBaseTokenReserves,
            _virtualNftReserves,
            _changeFee,
            _feeRate,
            _merkleRoot,
            _useStolenNftOracle,
            _payRoyalties
        );

        if (_baseToken == address(0)) {
            // transfer eth into the pool if base token is ETH
            address(privatePool).safeTransferETH(baseTokenAmount);
        } else {
            // deposit the base tokens from the caller into the pool
            ERC20(_baseToken).transferFrom(msg.sender, address(privatePool), baseTokenAmount);
        }

        // deposit the nfts from the caller into the pool
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ERC721(_nft).safeTransferFrom(msg.sender, address(privatePool), tokenIds[i]);
        }

        // emit create event
        emit Create(address(privatePool), tokenIds, baseTokenAmount);
    }

    /// @notice Sets private pool metadata contract.
    /// @param _privatePoolMetadata The private pool metadata contract.
    function setPrivatePoolMetadata(address _privatePoolMetadata) public onlyOwner {
        privatePoolMetadata = _privatePoolMetadata;
    }

    /// @notice Sets the private pool implementation contract that newly deployed proxies point to.
    /// @param _privatePoolImplementation The private pool implementation contract.
    function setPrivatePoolImplementation(address _privatePoolImplementation) public onlyOwner {
        privatePoolImplementation = _privatePoolImplementation;
    }

    /// @notice Sets the protocol fee that is taken on each buy/sell/change. It's in basis points: 350 = 3.5%.
    /// @param _protocolFeeRate The protocol fee.
    function setProtocolFeeRate(uint16 _protocolFeeRate) public onlyOwner {
        protocolFeeRate = _protocolFeeRate;
    }

    /// @notice Withdraws the earned protocol fees.
    /// @param token The token to withdraw.
    /// @param amount The amount to withdraw.
    function withdraw(address token, uint256 amount) public onlyOwner {
        if (token == address(0)) {
            msg.sender.safeTransferETH(amount);
        } else {
            ERC20(token).transfer(msg.sender, amount);
        }

        emit Withdraw(token, amount);
    }

    /// @notice Returns the token URI for a given token id.
    /// @param id The token id.
    /// @return uri The token URI.
    function tokenURI(uint256 id) public view override returns (string memory) {
        return PrivatePoolMetadata(privatePoolMetadata).tokenURI(id);
    }

    /// @notice Predicts the deployment address of a new private pool.
    /// @param salt The salt that will used on deployment.
    /// @return predictedAddress The predicted deployment address of the private pool.
    function predictPoolDeploymentAddress(bytes32 salt) public view returns (address predictedAddress) {
        predictedAddress = privatePoolImplementation.predictDeterministicAddress(salt, address(this));
    }
}