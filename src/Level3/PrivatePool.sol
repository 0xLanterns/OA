// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
 *                                   ____
 *                                /\|    ~~\
 *                              /'  |   ,-. `\
 *                             |       | X |  |
 *                            _|________`-'   |X
 *                          /'          ~~~~~~~~~,
 *                        /'             ,_____,/_
 *                     ,/'        ___,'~~         ;
 * ~~~~~~~~|~~~~~~~|---          /  X,~~~~~~~~~~~~,
 *         |       |            |  XX'____________'
 *         |       |           /' XXX|            ;
 *         |       |        --x|  XXX,~~~~~~~~~~~~,
 *         |       |          X|     '____________'
 *         |   o   |---~~~~\__XX\             |XX
 *         |       |          XXX`\          /XXXX
 * ~~~~~~~~'~~~~~~~'               `\xXXXXx/' \XXX
 *                                  /XXXXXX\
 *                                /XXXXXXXXXX\
 *                              /XXXXXX/^\XXXXX\
 *                             ~~~~~~~~   ~~~~~~~
 */

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";
import {ERC721, ERC721TokenReceiver} from "../../lib/solmate/src/tokens/ERC721.sol";
import {FixedPointMathLib} from "../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "../../lib/solmate/src/utils/SafeTransferLib.sol";
import {MerkleProofLib} from "../../lib/solady/src/utils/MerkleProofLib.sol";
import {IERC2981} from "../../lib/openzeppelin-contracts/contracts/interfaces/IERC2981.sol";
import {IRoyaltyRegistry} from "./context/IRoyaltyRegistry.sol";

import {IStolenNftOracle} from "./context/IStolenNftOracle.sol";
import {Factory} from "./context/Factory.sol";

/// @title Private Pool
/// @author out.eth (@outdoteth)
/// @notice A private pool is a an NFT AMM controlled by a single owner with concentrated liquidity, custom fee rates,
/// stolen NFT filtering, custom NFT weightings, royalty support, and flash loans. You can create a pool and change
/// these parameters to your liking. Deposit NFTs and base tokens (or ETH) into the pool to enable trading. Earn fees on
/// each trade.
contract PrivatePool is ERC721TokenReceiver {
    using SafeTransferLib for address payable;
    using SafeTransferLib for address;
    using SafeTransferLib for ERC20;

    /// @notice Merkle proof input for a sparse merkle multi proof. It can be generated with a library like:
    /// https://github.com/OpenZeppelin/merkle-tree#treegetmultiproof
    struct MerkleMultiProof {
        bytes32[] proof;
        bool[] flags;
    }

    // forgefmt: disable-start
    event Initialize(address indexed baseToken, address indexed nft, uint128 virtualBaseTokenReserves, uint128 virtualNftReserves, uint56 changeFee, uint16 feeRate, bytes32 merkleRoot, bool useStolenNftOracle, bool payRoyalties);
    event Buy(uint256[] tokenIds, uint256[] tokenWeights, uint256 inputAmount, uint256 feeAmount, uint256 protocolFeeAmount, uint256 royaltyFeeAmount);
    event Sell(uint256[] tokenIds, uint256[] tokenWeights, uint256 outputAmount, uint256 feeAmount, uint256 protocolFeeAmount, uint256 royaltyFeeAmount);
    event Deposit(uint256[] tokenIds, uint256 baseTokenAmount);
    event Withdraw(address indexed nft, uint256[] tokenIds, address token, uint256 amount);
    event Change(uint256[] inputTokenIds, uint256[] inputTokenWeights, uint256[] outputTokenIds, uint256[] outputTokenWeights, uint256 feeAmount, uint256 protocolFeeAmount);
    event SetVirtualReserves(uint128 virtualBaseTokenReserves, uint128 virtualNftReserves);
    event SetMerkleRoot(bytes32 merkleRoot);
    event SetFeeRate(uint16 feeRate);
    event SetUseStolenNftOracle(bool useStolenNftOracle);
    event SetPayRoyalties(bool payRoyalties);
    // forgefmt: disable-end
    error AlreadyInitialized();
    error Unauthorized();
    error InvalidEthAmount();
    error InvalidMerkleProof();
    error InsufficientInputWeight();
    error FeeRateTooHigh();

    error InvalidRoyaltyFee();

    /// @notice The address of the base ERC20 token.
    address public baseToken;

    /// @notice The address of the nft.
    address public nft;

    /// @notice The change/flash fee to 4 decimals of precision. For example, 0.0025 ETH = 25. 500 USDC = 5_000_000.
    uint56 public changeFee;

    /// @notice The buy/sell fee rate (in basis points) 200 = 2%
    uint16 public feeRate;

    /// @notice Whether or not the pool has been initialized.
    bool public initialized;

    /// @notice Whether or not the pool pays royalties to the NFT creator on each trade.
    bool public payRoyalties;

    /// @notice Whether or not the pool uses the stolen NFT oracle to check if an NFT is stolen.
    bool public useStolenNftOracle;

    /// @notice The virtual base token reserves used in the xy=k invariant. Changing this will change the liquidity
    /// depth and price of the pool.
    uint128 public virtualBaseTokenReserves;

    /// @notice The virtual nft reserves used in the xy=k invariant. Changing this will change the liquidity
    /// depth and price of the pool.
    /// @dev The virtual NFT reserves that a user sets. If it's desired to set the reserves to match 16 NFTs then the
    /// virtual reserves should be set to 16e18. If weights are enabled by setting the merkle root to be non-zero then
    /// the virtual reserves should be set to the sum of the weights of the NFTs; where floor NFTs all have a weight of
    /// 1e18. A rarer NFT may have a weight of 2.3e18 if it's 2.3x more valuable than a floor.
    uint128 public virtualNftReserves;

    /// @notice The merkle root of all the token weights in the pool. If the merkle root is set to bytes32(0) then all
    /// NFTs are set to have a weight of 1e18.
    bytes32 public merkleRoot;

    /// @notice The NFT oracle to check if an NFT is stolen.
    address public immutable stolenNftOracle;

    /// @notice The factory contract that created this pool.
    address payable public immutable factory;

    /// @notice The royalty registry from manifold.xyz.
    address public immutable royaltyRegistry;

    modifier onlyOwner() virtual {
        if (msg.sender != Factory(factory).ownerOf(uint160(address(this)))) {
            revert Unauthorized();
        }
        _;
    }

    receive() external payable {}

    /// @dev This is only called when the base implementation contract is deployed. The following immutable parameters
    /// are set:
    /// - factory: The address of the factory contract
    /// - royaltyRegistry: The address of the royalty registry from manifold.xyz
    /// - stolenNftOracle: The address of the stolen NFT oracle
    /// These are all stored in immutable storage, which enables all minimal proxy contracts to read them without
    /// incurring additional deployment costs and re-initializing them at point of creation in the factory contract.
    constructor(address _factory, address _royaltyRegistry, address _stolenNftOracle) {
        factory = payable(_factory);
        royaltyRegistry = _royaltyRegistry;
        stolenNftOracle = _stolenNftOracle;
    }

    /// @notice Initializes the private pool and sets the initial parameters. Should only be called once by the factory.
    /// @param _baseToken The address of the base token
    /// @param _nft The address of the NFT
    /// @param _virtualBaseTokenReserves The virtual base token reserves
    /// @param _virtualNftReserves The virtual NFT reserves
    /// @param _feeRate The fee rate (in basis points) 200 = 2%
    /// @param _merkleRoot The merkle root
    /// @param _useStolenNftOracle Whether or not the pool uses the stolen NFT oracle to check if an NFT is stolen
    function initialize(
        address _baseToken,
        address _nft,
        uint128 _virtualBaseTokenReserves,
        uint128 _virtualNftReserves,
        uint56 _changeFee,
        uint16 _feeRate,
        bytes32 _merkleRoot,
        bool _useStolenNftOracle,
        bool _payRoyalties
    ) public {
        // prevent duplicate initialization
        if (initialized) revert AlreadyInitialized();

        // check that the fee rate is less than 50%
        if (_feeRate > 5_000) revert FeeRateTooHigh();

        // set the state variables
        baseToken = _baseToken;
        nft = _nft;
        virtualBaseTokenReserves = _virtualBaseTokenReserves;
        virtualNftReserves = _virtualNftReserves;
        changeFee = _changeFee;
        feeRate = _feeRate;
        merkleRoot = _merkleRoot;
        useStolenNftOracle = _useStolenNftOracle;
        payRoyalties = _payRoyalties;

        // mark the pool as initialized
        initialized = true;

        // emit the event
        emit Initialize(
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
    }

    /// @notice Buys NFTs from the pool, paying with base tokens from the caller. Then transfers the bought NFTs to the
    /// caller. The net cost depends on the current price, fee rate and assigned NFT weights.
    /// @dev DO NOT call this function directly unless you know what you are doing. Instead, use a wrapper contract that
    /// will check the max input amount and revert if the slippage is too high.
    /// @param tokenIds The token IDs of the NFTs to buy.
    /// @param tokenWeights The weights of the NFTs to buy.
    /// @param proof The merkle proof for the weights of each NFT to buy.
    /// @return netInputAmount The amount of base tokens spent inclusive of fees.
    /// @return feeAmount The amount of base tokens spent on fees.
    function buy(uint256[] calldata tokenIds, uint256[] calldata tokenWeights, MerkleMultiProof calldata proof)
        public
        payable
        returns (uint256 netInputAmount, uint256 feeAmount, uint256 protocolFeeAmount)
    {
        // ~~~ Checks ~~~ //

        // calculate the sum of weights of the NFTs to buy
        uint256 weightSum = sumWeightsAndValidateProof(tokenIds, tokenWeights, proof);

        // calculate the required net input amount and fee amount
        (netInputAmount, feeAmount, protocolFeeAmount) = buyQuote(weightSum);

        // check that the caller sent 0 ETH if the base token is not ETH
        if (baseToken != address(0) && msg.value > 0) revert InvalidEthAmount();

        // ~~~ Effects ~~~ //

        // update the virtual reserves
        virtualBaseTokenReserves += uint128(netInputAmount - feeAmount - protocolFeeAmount);
        virtualNftReserves -= uint128(weightSum);

        // ~~~ Interactions ~~~ //

        // calculate the sale price (assume it's the same for each NFT even if weights differ)
        uint256 salePrice = (netInputAmount - feeAmount - protocolFeeAmount) / tokenIds.length;
        uint256 royaltyFeeAmount = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // transfer the NFT to the caller
            ERC721(nft).safeTransferFrom(address(this), msg.sender, tokenIds[i]);

            if (payRoyalties) {
                // get the royalty fee for the NFT
                (uint256 royaltyFee,) = _getRoyalty(tokenIds[i], salePrice);

                // add the royalty fee to the total royalty fee amount
                royaltyFeeAmount += royaltyFee;
            }
        }

        // add the royalty fee amount to the net input aount
        netInputAmount += royaltyFeeAmount;

        if (baseToken != address(0)) {
            // transfer the base token from the caller to the contract
            ERC20(baseToken).safeTransferFrom(msg.sender, address(this), netInputAmount);

            // if the protocol fee is set then pay the protocol fee
            if (protocolFeeAmount > 0) ERC20(baseToken).safeTransfer(address(factory), protocolFeeAmount);
        } else {
            // check that the caller sent enough ETH to cover the net required input
            if (msg.value < netInputAmount) revert InvalidEthAmount();

            // if the protocol fee is set then pay the protocol fee
            if (protocolFeeAmount > 0) factory.safeTransferETH(protocolFeeAmount);

            // refund any excess ETH to the caller
            if (msg.value > netInputAmount) msg.sender.safeTransferETH(msg.value - netInputAmount);
        }

        if (payRoyalties) {
            for (uint256 i = 0; i < tokenIds.length; i++) {
                // get the royalty fee for the NFT
                (uint256 royaltyFee, address recipient) = _getRoyalty(tokenIds[i], salePrice);

                // transfer the royalty fee to the recipient if it's greater than 0
                if (royaltyFee > 0 && recipient != address(0)) {
                    if (baseToken != address(0)) {
                        ERC20(baseToken).safeTransfer(recipient, royaltyFee);
                    } else {
                        recipient.safeTransferETH(royaltyFee);
                    }
                }
            }
        }

        // emit the buy event
        emit Buy(tokenIds, tokenWeights, netInputAmount, feeAmount, protocolFeeAmount, royaltyFeeAmount);
    }

    /// @notice Sells NFTs into the pool and transfers base tokens to the caller. NFTs are transferred from the caller
    /// to the pool. The net sale amount depends on the current price, fee rate and assigned NFT weights.
    /// @dev DO NOT call this function directly unless you know what you are doing. Instead, use a wrapper contract that
    /// will check the min output amount and revert if the slippage is too high.
    /// @param tokenIds The token IDs of the NFTs to sell.
    /// @param tokenWeights The weights of the NFTs to sell.
    /// @param proof The merkle proof for the weights of each NFT to sell.
    /// @param stolenNftProofs The proofs that show each NFT is not stolen.
    /// @return netOutputAmount The amount of base tokens received inclusive of fees.
    /// @return feeAmount The amount of base tokens to pay in fees.
    function sell(
        uint256[] calldata tokenIds,
        uint256[] calldata tokenWeights,
        MerkleMultiProof calldata proof,
        IStolenNftOracle.Message[] memory stolenNftProofs // put in memory to avoid stack too deep error
    ) public returns (uint256 netOutputAmount, uint256 feeAmount, uint256 protocolFeeAmount) {
        // ~~~ Checks ~~~ //

        // calculate the sum of weights of the NFTs to sell
        uint256 weightSum = sumWeightsAndValidateProof(tokenIds, tokenWeights, proof);

        // calculate the net output amount and fee amount
        (netOutputAmount, feeAmount, protocolFeeAmount) = sellQuote(weightSum);

        //  check the nfts are not stolen
        if (useStolenNftOracle) {
            IStolenNftOracle(stolenNftOracle).validateTokensAreNotStolen(nft, tokenIds, stolenNftProofs);
        }

        // ~~~ Effects ~~~ //

        // update the virtual reserves
        virtualBaseTokenReserves -= uint128(netOutputAmount + protocolFeeAmount + feeAmount);
        virtualNftReserves += uint128(weightSum);

        // ~~~ Interactions ~~~ //

        uint256 royaltyFeeAmount = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // transfer each nft from the caller
            ERC721(nft).safeTransferFrom(msg.sender, address(this), tokenIds[i]);

            if (payRoyalties) {
                // calculate the sale price (assume it's the same for each NFT even if weights differ)
                uint256 salePrice = (netOutputAmount + feeAmount + protocolFeeAmount) / tokenIds.length;

                // get the royalty fee for the NFT
                (uint256 royaltyFee, address recipient) = _getRoyalty(tokenIds[i], salePrice);

                // tally the royalty fee amount
                royaltyFeeAmount += royaltyFee;

                // transfer the royalty fee to the recipient if it's greater than 0
                if (royaltyFee > 0 && recipient != address(0)) {
                    if (baseToken != address(0)) {
                        ERC20(baseToken).safeTransfer(recipient, royaltyFee);
                    } else {
                        recipient.safeTransferETH(royaltyFee);
                    }
                }
            }
        }

        // subtract the royalty fee amount from the net output amount
        netOutputAmount -= royaltyFeeAmount;

        if (baseToken == address(0)) {
            // transfer ETH to the caller
            msg.sender.safeTransferETH(netOutputAmount);

            // if the protocol fee is set then pay the protocol fee
            if (protocolFeeAmount > 0) factory.safeTransferETH(protocolFeeAmount);
        } else {
            // transfer base tokens to the caller
            ERC20(baseToken).transfer(msg.sender, netOutputAmount);

            // if the protocol fee is set then pay the protocol fee
            if (protocolFeeAmount > 0) ERC20(baseToken).safeTransfer(address(factory), protocolFeeAmount);
        }

        // emit the sell event
        emit Sell(tokenIds, tokenWeights, netOutputAmount, feeAmount, protocolFeeAmount, royaltyFeeAmount);
    }

    /// @notice Changes a set of NFTs that the caller owns for another set of NFTs in the pool. The caller must approve
    /// the pool to transfer the NFTs. The sum of the caller's NFT weights must be less than or equal to the sum of the
    /// output pool NFTs weights. The caller must also pay a fee depending the net input weight and change fee amount.
    /// @param inputTokenIds The token IDs of the NFTs to change.
    function change(
        uint256[] memory inputTokenIds,
        uint256[] memory outputTokenIds
    ) public payable returns (uint256 feeAmount, uint256 protocolFeeAmount) {
        // ~~~ Checks ~~~ //

        // check that the caller sent 0 ETH if base token is not ETH
        if (baseToken != address(0) && msg.value > 0) revert InvalidEthAmount();



        // fix stack too deep
        {
            // calculate the sum of weights for the input nfts
            uint256 inputWeightSum = inputTokenIds.length * 1e18;

            uint256 outputWeightSum = outputTokenIds.length * 1e18;

            // check that the input weights are greater than or equal to the output weights
            if (inputWeightSum < outputWeightSum)
                //> can I swap 1 token for many
                revert InsufficientInputWeight();
            // calculate the fee amount
            (feeAmount) = changeFeeQuote(inputWeightSum);
        }

        // ~~~ Interactions ~~~ //

        if (baseToken != address(0)) {
            // transfer the fee amount of base tokens from the caller
            ERC20(baseToken).safeTransferFrom(msg.sender, address(this), feeAmount);
            // if the protocol fee is non-zero then transfer the protocol fee to the factory
            if (protocolFeeAmount > 0) ERC20(baseToken).safeTransferFrom(msg.sender, factory, protocolFeeAmount);
        } else {
            // check that the caller sent enough ETH to cover the fee amount and protocol fee
            if (msg.value < feeAmount) revert InvalidEthAmount();

            // refund any excess ETH to the caller
            if (msg.value > feeAmount) {
                msg.sender.safeTransferETH(msg.value - feeAmount);
            }
        }

        // transfer the input nfts from the caller
        for (uint256 i = 0; i < inputTokenIds.length; i++) {
            ERC721(nft).safeTransferFrom(msg.sender, address(this), inputTokenIds[i]);
        }

        // transfer the output nfts to the caller
        for (uint256 i = 0; i < outputTokenIds.length; i++) {
            ERC721(nft).transferFrom(address(this), msg.sender, outputTokenIds[i]);
        }

    }

    /// @notice Executes a transaction from the pool account to a target contract. The caller must be the owner of the
    /// pool. This allows for use cases such as claiming airdrops.
    /// @param target The address of the target contract.
    /// @param data The data to send to the target contract.
    /// @return returnData The return data of the transaction.
    function execute(address target, bytes memory data) public payable onlyOwner returns (bytes memory) {
        // call the target with the value and data
        (bool success, bytes memory returnData) = target.call{value: msg.value}(data);

        // if the call succeeded return the return data
        if (success) return returnData;

        // if we got an error bubble up the error message
        if (returnData.length > 0) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let returnData_size := mload(returnData)
                revert(add(32, returnData), returnData_size)
            }
        } else {
            revert();
        }
    }



    /// @notice Sums the weights of each NFT and validates that the weights are correct by verifying the merkle proof.
    /// @param tokenIds The token IDs of the NFTs to sum the weights for.
    /// @param tokenWeights The weights of each NFT in the token IDs array.
    /// @param proof The merkle proof for the weights of each NFT.
    /// @return sum The sum of the weights of each NFT.
    function sumWeightsAndValidateProof(
        uint256[] memory tokenIds,
        uint256[] memory tokenWeights,
        MerkleMultiProof memory proof
    ) public view returns (uint256) {
        // if the merkle root is not set then set the weight of each nft to be 1e18
        if (merkleRoot == bytes32(0)) {
            return tokenIds.length * 1e18;
        }

        uint256 sum;
        bytes32[] memory leafs = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // create the leaf for the merkle proof
            leafs[i] = keccak256(bytes.concat(keccak256(abi.encode(tokenIds[i], tokenWeights[i]))));

            // sum each token weight
            sum += tokenWeights[i];
        }

        // validate that the weights are valid against the merkle proof
        if (!MerkleProofLib.verifyMultiProof(proof.proof, merkleRoot, leafs, proof.flags)) {
            revert InvalidMerkleProof();
        }

        return sum;
    }

    /// @notice Returns the required input of buying a given amount of NFTs inclusive of the fee which is dependent on
    /// the currently set fee rate.
    /// @param outputAmount The amount of NFTs to buy multiplied by 1e18.
    /// @return netInputAmount The required input amount of base tokens inclusive of the fee.
    /// @return feeAmount The fee amount.
    function buyQuote(uint256 outputAmount)
        public
        view
        returns (uint256 netInputAmount, uint256 feeAmount, uint256 protocolFeeAmount)
    {
        // calculate the input amount based on xy=k invariant and round up by 1 wei
        uint256 inputAmount =
            FixedPointMathLib.mulDivUp(outputAmount, virtualBaseTokenReserves, (virtualNftReserves - outputAmount));

        protocolFeeAmount = inputAmount * Factory(factory).protocolFeeRate() / 10_000;
        feeAmount = inputAmount * feeRate / 10_000;
        netInputAmount = inputAmount + feeAmount + protocolFeeAmount;
    }

    /// @notice Returns the output amount of selling a given amount of NFTs inclusive of the fee which is dependent on
    /// the currently set fee rate.
    /// @param inputAmount The amount of NFTs to sell multiplied by 1e18.
    /// @return netOutputAmount The output amount of base tokens inclusive of the fee.
    /// @return feeAmount The fee amount.
    function sellQuote(uint256 inputAmount)
        public
        view
        returns (uint256 netOutputAmount, uint256 feeAmount, uint256 protocolFeeAmount)
    {
        // calculate the output amount based on xy=k invariant
        uint256 outputAmount = inputAmount * virtualBaseTokenReserves / (virtualNftReserves + inputAmount);

        protocolFeeAmount = outputAmount * Factory(factory).protocolFeeRate() / 10_000;
        feeAmount = outputAmount * feeRate / 10_000;
        netOutputAmount = outputAmount - feeAmount - protocolFeeAmount;
    }

    /// @notice Returns the fee required to change a given amount of NFTs. The fee is based on the current changeFee
    /// (which contains 4 decimals of precision) multiplied by some exponent depending on the base token decimals.
    /// @param inputAmount The amount of NFTs to change multiplied by 1e18.
    /// @return feeAmount The fee amount.
    function changeFeeQuote(uint256 inputAmount) public view returns (uint256 feeAmount) {
        // multiply the changeFee to get the fee per NFT (4 decimals of accuracy)
        uint256 exponent = baseToken == address(0) ? 18 - 4 : ERC20(baseToken).decimals() - 4;
        uint256 feePerNft = changeFee * 10 ** exponent;

        feeAmount = inputAmount * feePerNft / 1e18;

    }

    /// @notice Returns the price of the pool to 18 decimals of accuracy.
    /// @return price The price of the pool.
    function price() public view returns (uint256) {
        // ensure that the exponent is always to 18 decimals of accuracy
        uint256 exponent = baseToken == address(0) ? 18 : (36 - ERC20(baseToken).decimals());
        return (virtualBaseTokenReserves * 10 ** exponent) / virtualNftReserves;
    }

    /// @notice Gets the royalty and recipient for a given NFT and sale price. Looks up the royalty info from the
    /// manifold registry.
    /// @param tokenId The token ID of the NFT.
    /// @param salePrice The sale price of the NFT.
    /// @return royaltyFee The royalty fee to pay.
    /// @return recipient The address to pay the royalty fee to.
    function _getRoyalty(uint256 tokenId, uint256 salePrice)
        internal
        view
        returns (uint256 royaltyFee, address recipient)
    {
        // get the royalty lookup address
        address lookupAddress = IRoyaltyRegistry(royaltyRegistry).getRoyaltyLookupAddress(nft);

        if (IERC2981(lookupAddress).supportsInterface(type(IERC2981).interfaceId)) {
            // get the royalty fee from the registry
            (recipient, royaltyFee) = IERC2981(lookupAddress).royaltyInfo(tokenId, salePrice);

            // revert if the royalty fee is greater than the sale price
            if (royaltyFee > salePrice) revert InvalidRoyaltyFee();
        }
    }
}