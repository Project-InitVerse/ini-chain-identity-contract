// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAuditor{
    function getProviderCheckJson(address provider) external view returns(string memory);
    function admin() external view returns(address);
    function name() external view returns(string memory);
}
enum providerState {
    unSet,checked,checkFail
}
interface IAuditorFactory{
    function reportProviderState(address provider, providerState state) external;
    function getProviderAuditors(address provider) external view returns(address[] memory);
    function getProviderJson(address auditor,address provider) external view returns(string memory);
}
