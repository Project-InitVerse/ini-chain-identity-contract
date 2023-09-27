// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IProviderFactory {

    // @notice Returns provider contract address if account is a provider else return 0x0
    function getProvideContract(address account) external view returns (address);
    // @notice Returns provider contract available resources
    function getProvideResource(address account) external view returns (poaResource memory);
    // @notice Returns provider contract total resources
    function getProvideTotalResource(address account) external view returns (poaResource memory);
    // @notice Provide notify factory change total resources
    function changeProviderResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external;
    // @notice Provide notify factory change used resources
    function changeProviderUsedResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external;
    // @notice Order use to consume provider resource
    function consumeResource(address account, uint256 cpu_count, uint256 mem_count, uint256 storage_count) external;
    // @notice Order use to recover provider resource
    function recoverResource(address account, uint256 cpu_count, uint256 mem_count, uint256 storage_count) external;

    function punish_start_limit() external view returns (uint256);

    function punish_interval() external view returns (uint256);

    function getPunishAmount(uint256 punish_amount) external view returns (uint256);

    function punish_address() external view returns (address);

    function punish_item_address() external view returns (address);

    function removeProviderPunishList(address provider) external;

    function provider_lock_time() external view returns (uint256);
}
    struct poaResource {
        uint256 cpu_count;
        uint256 memory_count;
        uint256 storage_count;
    }
    struct marginInfo {
        // provider margin block
        uint256 margin_block;
        // provider margin amount
        uint256 margin_amount;
        // provider margin has withdrawn or not
        bool withdrawn;
        // provider margin time
        uint256 margin_time;
        // provider margin lock time
        uint256 margin_lock_time;
        // provider has been deducted quota when this margin add
        uint256 deducted_quota_numerator;
        uint256 deducted_quota_denominator;
    }
    struct marginViewInfo {
        // provider margin amount
        uint256 margin_amount;
        // provider margin has withdrawn or not
        bool withdrawn;
        // provider margin time
        uint256 margin_time;
        // provider margin lock time
        uint256 margin_lock_time;
        // provider margin remain amount
        uint256 remain_margin_amount;
    }
    enum ProviderState{
        Running,
        Punish,
        Pause,
        Stop
    }
    struct providerInfo {
        poaResource total;
        poaResource used;
        poaResource lock;
        bool challenge;
        ProviderState state;
        address owner;
        string region;
        string info;
        uint256 last_challenge_time;
        uint256 last_margin_time;
        marginViewInfo[] margin_infos;
    }
interface IProvider {
    function getLeftResource() external view returns (poaResource memory);

    function getTotalResource() external view returns (poaResource memory);

    function consumeResource(uint256, uint256, uint256) external;

    function recoverResource(uint256, uint256, uint256) external;

    function owner() external view returns (address);

    function info() external view returns (string memory);

    function getDetail() external view returns (providerInfo memory);

    function last_margin_time() external view returns (uint256);

    function withdrawMargin(uint256 index) external;

    function withdrawMargins() external;

    function removePunish() external;

    function punish() external;

    function startChallenge(bool) external;

    function challenge() external view returns (bool);

    function getRemainMarginAmount(uint256 index) external view returns (uint256);
}
