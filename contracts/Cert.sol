// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
    enum CertState {
        Deleted, Using
    }
contract Cert {
    struct certInfo {
        uint256 createTime;
        uint256 remainTime;
        address user;
        uint256 index;
        CertState state;
    }

    struct certRetInfo {
        uint256 createTime;
        uint256 remainTime;
        address user;
        CertState state;
        string cert;
        uint256 index;
    }

    event CertCreate(uint256, address, uint256, CertState);
    event CertStateChange(uint256, address, CertState);

    mapping(address => string[])user_cert;
    mapping(string => certInfo) public cert_user;

    function user_cert_state(address user, string memory cert) external view returns (CertState){
        require(user == cert_user[cert].user, "Cert : not this user cert");
        return cert_user[cert].state;
    }

    function createNewCert(string memory new_cert, uint256 remain_time, CertState _state) public {
        require(cert_user[new_cert].createTime == 0);
        user_cert[msg.sender].push(new_cert);
        certInfo memory info;
        info.createTime = block.timestamp;
        info.user = msg.sender;
        info.remainTime = block.timestamp + remain_time;
        info.state = _state;
        info.index = user_cert[msg.sender].length - 1;
        cert_user[new_cert] = info;
        emit CertCreate(info.index, info.user, info.remainTime, info.state);
    }

    function changeCertState(string memory cert, CertState _state) public {
        require(msg.sender == cert_user[cert].user);
        cert_user[cert].state = _state;
        certInfo memory info;
        info = cert_user[cert];
        emit CertStateChange(info.index, info.user, _state);
    }

    function getAllUserCert(address user) public view returns (certRetInfo[] memory){
        certRetInfo[] memory _provider_auditors = new certRetInfo[](user_cert[user].length);
        for (uint256 i = 0; i < user_cert[user].length; i++) {
            _provider_auditors[i].cert = user_cert[user][i];
            _provider_auditors[i].user = cert_user[user_cert[user][i]].user;
            _provider_auditors[i].createTime = cert_user[user_cert[user][i]].createTime;
            _provider_auditors[i].remainTime = cert_user[user_cert[user][i]].remainTime;
            _provider_auditors[i].state = cert_user[user_cert[user][i]].state;
            _provider_auditors[i].index = cert_user[user_cert[user][i]].index;
        }
        return _provider_auditors;
    }

    function getUserCert(address user, uint256 index) public view returns (certRetInfo memory){
        require(user_cert[user].length > index);
        certRetInfo memory ret;
        ret.cert = user_cert[user][index];
        ret.state = cert_user[user_cert[user][index]].state;
        ret.createTime = cert_user[user_cert[user][index]].createTime;
        ret.remainTime = cert_user[user_cert[user][index]].remainTime;
        ret.user = cert_user[user_cert[user][index]].user;
        ret.index = cert_user[user_cert[user][index]].index;
        return ret;
    }
}
