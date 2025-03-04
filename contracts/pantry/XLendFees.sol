// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../amm-v1/interfaces/IUniswapV2Pair.sol";
import "../amm-v1/interfaces/IUniswapV2Factory.sol";

interface IVaultWithdraw {
    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

interface IKashiWithdrawFee {
    function asset() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function withdrawFees() external;

    function removeAsset(address to, uint256 fraction)
        external
        returns (uint256 share);
}

// XLendFees contract handles "serving up" rewards for XREACT holders by trading tokens collected from Kashi fees for REACT.
contract XLendFees is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IUniswapV2Factory private immutable factory;
    //0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac
    address private immutable bar;
    //0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272
    IVaultWithdraw private immutable vault;
    //0xF5BCE5077908a1b7370B9ae04AdC565EBd643966
    address private immutable react;
    //0x6B3595068778DD592e39A122f4f5a5cF09C90fE2
    address private immutable weth;
    //0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
    bytes32 private immutable pairCodeHash;
    //0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303

    mapping(address => address) private _bridges;

    event LogBridgeSet(address indexed token, address indexed bridge);
    event LogConvert(
        address indexed server,
        address indexed token0,
        uint256 amount0,
        uint256 amountVAULT,
        uint256 amountREACT
    );

    constructor(
        IUniswapV2Factory _factory,
        address _bar,
        IVaultWithdraw _vault,
        address _react,
        address _weth,
        bytes32 _pairCodeHash
    ) {
        factory = _factory;
        bar = _bar;
        vault = _vault;
        react = _react;
        weth = _weth;
        pairCodeHash = _pairCodeHash;
    }

    function setBridge(address token, address bridge) external onlyOwner {
        // Checks
        require(
            token != react && token != weth && token != bridge,
            "Maker: Invalid bridge"
        );
        // Effects
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    modifier onlyEOA() {
        // Try to make flash-loan exploit harder to do by only allowing externally-owned addresses.
        require(msg.sender == tx.origin, "Maker: Must use EOA");
        _;
    }

    function convert(IKashiWithdrawFee kashiPair) external onlyEOA {
        _convert(kashiPair);
    }

    function convertMultiple(IKashiWithdrawFee[] calldata kashiPair)
        external
        onlyEOA
    {
        for (uint256 i = 0; i < kashiPair.length; i++) {
            _convert(kashiPair[i]);
        }
    }

    function _convert(IKashiWithdrawFee kashiPair) private {
        // update Kashi fees for this Maker contract (`feeTo`)
        kashiPair.withdrawFees();

        // convert updated Kashi balance to pantry shares
        uint256 vaultShares =
            kashiPair.removeAsset(
                address(this),
                kashiPair.balanceOf(address(this))
            );

        // convert pantry shares to underlying Kashi asset (`token0`) balance (`amount0`) for Maker
        address token0 = kashiPair.asset();
        (uint256 amount0, ) =
            vault.withdraw(
                IERC20(token0),
                address(this),
                address(this),
                0,
                vaultShares
            );

        emit LogConvert(
            msg.sender,
            token0,
            amount0,
            vaultShares,
            _convertStep(token0, amount0)
        );
    }

    function _convertStep(address token0, uint256 amount0)
        private
        returns (uint256 reactOut)
    {
        if (token0 == react) {
            IERC20(token0).safeTransfer(bar, amount0);
            reactOut = amount0;
        } else if (token0 == weth) {
            reactOut = _swap(token0, react, amount0, bar);
        } else {
            address bridge = _bridges[token0];
            if (bridge == address(0)) {
                bridge = weth;
            }
            uint256 amountOut = _swap(token0, bridge, amount0, address(this));
            reactOut = _convertStep(bridge, amountOut);
        }
    }

    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) private returns (uint256 amountOut) {
        (address token0, address token1) =
            fromToken < toToken ? (fromToken, toToken) : (toToken, fromToken);
        IUniswapV2Pair pair =
            IUniswapV2Pair(
                address(
                    uint160(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    hex"ff",
                                    factory,
                                    keccak256(abi.encodePacked(token0, token1)),
                                    pairCodeHash
                                )
                            )
                        )
                    )
                )
            );

        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);

        if (toToken > fromToken) {
            amountOut =
                amountInWithFee.mul(reserve1) /
                reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, "");
        } else {
            amountOut =
                amountInWithFee.mul(reserve0) /
                reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, "");
        }
    }
}
