// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

interface IReactMaster {
    using BoringERC20 for IERC20;
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. REACT to distribute per block.
        uint256 lastRewardBlock; // Last block number that REACT distribution occurs.
        uint256 accReactPerShare; // Accumulated REACT per share, times 1e12. See below.
    }

    function poolInfo(uint256 pid)
        external
        view
        returns (IReactMaster.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;
}
