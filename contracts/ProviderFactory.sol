// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ReentrancyGuard.sol";
import "./InterfaceProvider.sol";
import "./InterfaceAuditor.sol";
import "./InterfaceOrderFactory.sol";
import "./SortList.sol";
import "./IPunishContract.sol";

contract Provider is IProvider, ReentrancyGuard {
    // provider total resource
    poaResource public total;
    // provider user used resource
    poaResource public used;
    // provider lock resource
    poaResource public lock;
    // provider whether in challenge
    bool public override challenge;
    // provider state
    ProviderState public state;
    // provider contract owner
    address public override owner;
    // provider region
    string public region;
    // provider first margin time
    uint256 public provider_first_margin_time;
    // provider last margin time
    uint256 public override last_margin_time;
    // provider last challenge time
    uint256 public last_challenge_time;
    // provider margin block
    uint256 public margin_block;
    // provider margin map
    mapping(uint256 => marginInfo) public margin_infos;
    // provider margin size
    uint256 public margin_size;
    // provider remain quota
    uint256 public remain_quota_numerator;
    uint256 public remain_quota_denominator;
    // provider punish start time
    uint256 public punish_start_time;
    // provider margin amount at punish start time
    uint256 public punish_start_margin_amount;
    // provider last punish time
    uint256 public last_punish_time;
    // provider info
    string  public override info;
    // punish event
    event Punish(address indexed, uint256 indexed, uint256 indexed);
    // margin add event
    event MarginAdd(address indexed, uint256 indexed, uint256 indexed);
    // margin withdraw event
    event MarginWithdraw(address indexed, uint256 indexed);
    // state change event
    event StateChange(address indexed, uint256 indexed);
    // challenge state change
    event ChallengeStateChange(address indexed, bool);
    // provider factroy address
    //TODO for formal
    IProviderFactory public constant provider_factory = IProviderFactory(0x000000000000000000000000000000000000C003);
    //TODO for test
    //IProviderFactory public provider_factory;
    // @dev Initialization parameters
    constructor(uint256 cpu_count,
        uint256 mem_count,
        uint256 storage_count,
        address _owner,
        string memory _region,
        string memory provider_info){
        //TODO for test
        //provider_factory = IProviderFactory(msg.sender);
        total.cpu_count = cpu_count;
        total.memory_count = mem_count;
        total.storage_count = storage_count;
        owner = _owner;
        info = provider_info;
        challenge = false;
        emit ChallengeStateChange(owner, challenge);
        region = _region;
        state = ProviderState.Running;
        emit StateChange(owner, uint256(state));
        provider_first_margin_time = block.timestamp;
        last_margin_time = block.timestamp;
        margin_block = block.number;
        remain_quota_numerator = 1;
        remain_quota_denominator = 1;
    }
    // @dev get unused resource
    function getLeftResource() public view override returns (poaResource memory){
        poaResource memory left;
        left.cpu_count = total.cpu_count - used.cpu_count;
        left.memory_count = total.memory_count - used.memory_count;
        left.storage_count = total.storage_count - used.storage_count;
        return left;
    }
    // @dev get remain margin amount
    function getRemainMarginAmount(uint256 index) public view override returns (uint256){
        if (margin_infos[index].withdrawn) {
            return 0;
        }
        // (remain_quota_numerator/remain_quota_denominator) / (margin_infos[index].remain_quota_numerator/margin_infos[index].remain_quota_denominator)
        // = (remain_quota_numerator * margin_infos[index].remain_quota_denominator) / (remain_quota_denominator * margin_infos[index].remain_quota_numerator)
        uint256 numerator = remain_quota_numerator * margin_infos[index].remain_quota_denominator;
        uint256 denominator = remain_quota_denominator * margin_infos[index].remain_quota_numerator;

        return margin_infos[index].margin_amount * numerator / denominator;
    }
    // @dev withdraw margin amount
    function withdrawMargins() external override onlyFactory {
        uint256 balance_before = address(this).balance;
        sendValue(payable(owner), address(this).balance);
        for (uint256 i = 0; i < margin_size; i++) {
            margin_infos[i].withdrawn = true;
        }

        emit MarginWithdraw(owner, balance_before);
    }
    // @dev withdraw margin amount
    function withdrawMargin(uint256 index) external override onlyFactory {
        require(index >=0 && index < margin_size, "invalid margin index");
        require(margin_infos[index].margin_time + margin_infos[index].margin_lock_time < block.timestamp, "time not enough");

        uint256 balance_before = address(this).balance;
        sendValue(payable(owner), getRemainMarginAmount(index));
        margin_infos[index].withdrawn = true;

        emit MarginWithdraw(owner, balance_before);
    }
    // @dev remove punish state
    function removePunish() external override onlyFactory {
        punish_start_time = 0;
        last_punish_time = 0;
        if (state == ProviderState.Punish || state == ProviderState.Pause) {
            state = ProviderState.Running;
            emit StateChange(owner, uint256(state));
        }
    }
    // @dev punish function
    function punish() external override onlyFactory {
        if (block.timestamp - punish_start_time > provider_factory.punish_start_limit() && punish_start_time != 0) {
            if (block.timestamp - last_punish_time > provider_factory.punish_interval()) {
                last_punish_time = block.timestamp;
                uint256 PunishAmount = (provider_factory).getPunishAmount(punish_start_margin_amount);
                uint256 _punishAmount = address(this).balance >= PunishAmount ? PunishAmount : address(this).balance;
                if (_punishAmount > 0) {
                    // update remain quota
                    remain_quota_numerator = remain_quota_numerator * (address(this).balance - _punishAmount);
                    remain_quota_denominator = remain_quota_denominator * address(this).balance;

                    sendValue(payable(provider_factory.punish_address()), _punishAmount);

                    if (provider_factory.punish_item_address() != address(0)) {
                        IPunishContract(provider_factory.punish_item_address()).newPunishItem(owner, _punishAmount, address(this).balance);
                    }
                    emit Punish(owner, _punishAmount, address(this).balance);
                }
            }
            if (address(this).balance == 0) {
                state = ProviderState.Pause;
                provider_factory.removeProviderPunishList(owner);
                punish_start_time = 0;
                last_punish_time = 0;
                emit StateChange(owner, uint256(state));
            }
        } else {
            if (state == ProviderState.Running) {
                state = ProviderState.Punish;
                emit StateChange(owner, uint256(state));
                punish_start_time = block.timestamp;
                punish_start_margin_amount = address(this).balance;
            }
        }
    }
    // @dev internal function for transfer value
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "insufficient balance");
        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success,) = recipient.call{value : amount}("");
        require(success, "unable to send value, recipient may have reverted");
    }
    // @dev add margin
    receive() external payable onlyFactory {
        margin_block = block.number;
        last_margin_time = block.timestamp;
        // add new margin info
        margin_infos[margin_size++] = marginInfo(block.number, msg.value, false, block.timestamp,
            provider_factory.provider_lock_time(), remain_quota_numerator, remain_quota_denominator);
        if (state == ProviderState.Pause) {
            state = ProviderState.Running;
            emit StateChange(owner, uint256(state));
        }
        emit MarginAdd(owner, msg.value, address(this).balance);
    }
    // @dev provider resource change event
    event ProviderResourceChange(address);
    // @dev only factory
    modifier onlyFactory(){
        require(msg.sender == address(provider_factory), "factory only");
        _;
    }
    // @dev only owner
    modifier onlyOwner{
        require(msg.sender == owner, "owner only");
        _;
    }
    // @dev only not stop state
    modifier onlyNotStop{
        require(state != ProviderState.Stop, "only not stop");
        _;
    }
    // @dev change provider info
    function changeProviderInfo(string memory new_info) public onlyOwner {
        info = new_info;
    }
    // @dev change provider region
    function changeRegion(string memory _new_region) public onlyOwner {
        region = _new_region;
    }
    // @dev get provider info detail
    function getDetail() external view override returns (providerInfo memory){
        providerInfo memory ret;
        ret.total = total;
        ret.used = used;
        ret.lock = lock;
        ret.region = region;
        ret.state = state;
        ret.owner = owner;
        ret.info = info;
        ret.challenge = challenge;
        ret.last_challenge_time = last_challenge_time;
        ret.last_margin_time = last_margin_time;
        marginViewInfo[] memory margin_view_infos = new marginViewInfo[](margin_size);
        for(uint256 i = 0; i < margin_size; i++) {
            margin_view_infos[i] = marginViewInfo(margin_infos[i].margin_amount, margin_infos[i].withdrawn,
                margin_infos[i].margin_time, margin_infos[i].margin_lock_time, getRemainMarginAmount(i));
        }
        ret.margin_infos = margin_view_infos;
        return ret;
    }

    // @dev get total resource
    function getTotalResource() external override view returns (poaResource memory){
        return total;
    }
    // @dev consume provider resource
    function consumeResource(uint256 consume_cpu, uint256 consume_mem, uint256 consume_storage) external override onlyFactory nonReentrant {
        poaResource memory _left = getLeftResource();
        require(consume_cpu <= _left.cpu_count && consume_mem <= _left.memory_count && consume_storage <= _left.storage_count, "resource left not enough");
        provider_factory.changeProviderUsedResource(used.cpu_count, used.memory_count, used.storage_count, false);
        used.cpu_count = used.cpu_count + consume_cpu;
        used.memory_count = used.memory_count + consume_mem;
        used.storage_count = used.storage_count + consume_storage;
        provider_factory.changeProviderUsedResource(used.cpu_count, used.memory_count, used.storage_count, true);
        emit ProviderResourceChange(address(this));
    }
    // @dev recover provider resource
    function recoverResource(uint256 consumed_cpu, uint256 consumed_mem, uint256 consumed_storage) external override onlyFactory nonReentrant {
        if ((consumed_cpu > used.cpu_count) ||
        (consumed_mem > used.memory_count) ||
            (consumed_storage > used.storage_count)) {
            provider_factory.changeProviderResource(total.cpu_count, total.memory_count, total.storage_count, false);
            total.cpu_count = used.cpu_count;
            total.memory_count = used.memory_count;
            total.storage_count = used.storage_count;
            provider_factory.changeProviderResource(used.cpu_count, used.memory_count, used.storage_count, true);
        } else {
            provider_factory.changeProviderUsedResource(used.cpu_count, used.memory_count, used.storage_count, false);
            used.cpu_count = used.cpu_count - consumed_cpu;
            used.memory_count = used.memory_count - consumed_mem;
            used.storage_count = used.storage_count - consumed_storage;
            provider_factory.changeProviderUsedResource(used.cpu_count, used.memory_count, used.storage_count, true);
        }
        emit ProviderResourceChange(address(this));
    }

    // @dev owner update resource
    function updateResource(uint256 new_cpu_count, uint256 new_mem_count, uint256 new_sto_count) external onlyOwner onlyNotStop {
        provider_factory.changeProviderResource(total.cpu_count, total.memory_count, total.storage_count, false);
        total.cpu_count = used.cpu_count + new_cpu_count;
        total.memory_count = used.memory_count + new_mem_count;
        total.storage_count = used.storage_count + new_sto_count;
        provider_factory.changeProviderResource(total.cpu_count, total.memory_count, total.storage_count, true);
        emit ProviderResourceChange(address(this));
    }
    // @dev factory change challenge state
    function startChallenge(bool whether_start) external override onlyFactory {
        if (whether_start) {
            last_challenge_time = block.timestamp;
        }
        challenge = whether_start;
        emit ChallengeStateChange(owner, challenge);
    }
}

contract ProviderFactory is IProviderFactory, ReentrancyGuard {
    using SortLinkedList for SortLinkedList.List;
    constructor (){

    }
    // @dev Initialization parameters
    function initialize(address _admin) external onlyNotInitialize {
        initialized = true;
        admin = _admin;
        punish_address = _admin;
        min_value_tobe_provider = 1000 ether;
        max_value_tobe_provider = 10000 ether;
        punish_percent = 100;
        punish_all_percent = 10000;
        punish_start_limit = 48 hours;
        punish_interval = 1 days;
        decimal_cpu = 1000;
        decimal_memory = 1024 * 1024 * 1024 * 4;
        provider_lock_time = 365 days;
    }
    // provider lock margin amount time default is 365 days
    uint256 public provider_lock_time;
    // provider min per-unit margin amount to join por get reward
    uint256 public min_value_tobe_provider;
    // provider max per-unit margin amount to join por get reward
    uint256 public max_value_tobe_provider;
    // calc cpu per-unit default is 1000m cpu
    uint256 public decimal_cpu;
    // calc memory per-unit default is 4 Gi
    uint256 public decimal_memory;
    // percent of provider punish default is 100 all is 10000 = 1%
    uint256 public punish_percent;
    // punish all percent
    uint256 public punish_all_percent;
    // time limit to start punish default is 48 hours
    uint256 public override punish_start_limit;
    // punish interval time default is 1 day
    uint256 public override punish_interval;
    // address get punish amount
    address public override punish_address;
    // provider factory whether initialized
    bool public initialized;
    // all provider supply resource
    poaResource public total_all;
    // all used resource
    poaResource public total_used;
    // punish items contract
    //TODO formal
    address public constant override punish_item_address = address(0x000000000000000000000000000000000000C005);
    //TODO for test
    //address public override punish_item_address;
    // map from provider owner to provider contract
    mapping(address => IProvider) public providers;
    address public constant val_factory = address(0x000000000000000000000000000000000000c002);
    //mapping(address => uint256) public provider_pledge;
    //provider array
    IProvider[] provider_array;
    // address of order factory
    address public order_factory;
    // admin address
    address public admin;
    // address of auditor factory
    address public auditor_factory;
    // provider punish list
    SortLinkedList.List provider_punish_pools;

    struct providerInfos {
        address provider_contract;
        providerInfo info;
        uint256 margin_amount;
        address[] audits;
    }
    // provider create event
    event ProviderCreate(address);
    // @dev only admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "admin only");
        _;
    }
    // @dev only miner
    modifier onlyMiner() {
        require(msg.sender == block.coinbase, "Miner only");
        _;
    }
    // @dev only provider contract
    modifier onlyProvider(){
        require(providers[IProvider(msg.sender).owner()] != IProvider(address(0)), "provider contract only");
        require(providers[IProvider(msg.sender).owner()] == IProvider(msg.sender), "provider contract equal");
        _;
    }
    // @dev only not initialize
    modifier onlyNotInitialize(){
        require(!initialized, "only not initialize");
        _;
    }
    // @dev only not provider owner
    modifier onlyNotProvider(){
        require(providers[msg.sender] == IProvider(address(0)), "only not provider");
        _;
    }
    // @dev only validator factory
    modifier onlyValidator(){
        require(msg.sender == val_factory, "only val_fac");
        _;
    }
    //TODO for test
    //    function changeProviderPunishItemAddr(address new_punish_item) public onlyAdmin {
    //        punish_item_address = new_punish_item;
    //    }
    // @dev change punish address
    function changePunishAddress(address _punish_address) public onlyAdmin {
        punish_address = _punish_address;
    }
    // @dev change provider margin amount lock time
    function changeProviderLockTime(uint256 _lock_time) public onlyAdmin {
        provider_lock_time = _lock_time;
    }
    // @dev change punish percent
    function changePunishPercent(uint256 _new_punish_percent, uint256 _new_punish_all_percent) external onlyAdmin {
        require(_new_punish_percent <= _new_punish_all_percent, "percent error");
        punish_percent = _new_punish_percent;
        punish_all_percent = _new_punish_all_percent;
    }
    // @dev change provider margin limit to join POR
    function changeProviderLimit(uint256 _new_min, uint256 _new_max) public onlyAdmin {
        min_value_tobe_provider = _new_min;
        max_value_tobe_provider = _new_max;
    }
    // @dev change punish start time and punish interval
    function changePunishParam(uint256 _new_punish_start_limit, uint256 _new_punish_interval) public onlyAdmin {
        punish_start_limit = _new_punish_start_limit;
        punish_interval = _new_punish_interval;
    }
    // @dev change por per unit
    function changeDecimal(uint256 new_cpu_decimal, uint256 new_memory_decimal) external onlyAdmin {
        decimal_cpu = new_cpu_decimal;
        decimal_memory = new_memory_decimal;
    }
    // @dev provider owner add margin
    function addMargin() public payable {
        require(providers[msg.sender] != IProvider(address(0)), "only provider owner");
        poaResource memory temp_total = providers[msg.sender].getTotalResource();
        (uint256 limit_min,uint256 limit_max) = calcProviderAmount(temp_total.cpu_count, temp_total.memory_count);
        require(address(providers[msg.sender]).balance + msg.value >= limit_min && address(providers[msg.sender]).balance + msg.value <= limit_max, "pledge money range error");
        //provider_pledge[msg.sender] =provider_pledge[msg.sender] + msg.value;
        (bool sent,) = (address(providers[msg.sender])).call{value : msg.value}("");
        require(sent, "add Margin fail");
    }
    // @dev provider owner withdraw margin
    function withdrawMargin(uint256 index) public {
        require(providers[msg.sender] != IProvider(address(0)), "only provider owner");
        providers[msg.sender].withdrawMargin(index);
    }
    // @dev create new provider
    function createNewProvider(uint256 cpu_count,
        uint256 mem_count,
        uint256 storage_count,
        string memory region,
        string memory provider_info)
    onlyNotProvider
    public payable returns (address){
        (uint256 limit_min,uint256 limit_max) = calcProviderAmount(cpu_count, mem_count);
        if (limit_min != 0 && limit_max != 0) {
            require(msg.value >= limit_min && msg.value <= limit_max, "must pledge money");
        }
        Provider provider_contract = new Provider(cpu_count, mem_count, storage_count, msg.sender, region, provider_info);
        total_all.cpu_count = total_all.cpu_count + cpu_count;
        total_all.memory_count = total_all.memory_count + mem_count;
        total_all.storage_count = total_all.storage_count + storage_count;

        provider_array.push(provider_contract);
        providers[msg.sender] = provider_contract;
        if (msg.value > 0) {
            (bool sent,) = (address(provider_contract)).call{value : msg.value}("");
            require(sent, "add Margin fail");
        }

        emit ProviderCreate(address(provider_contract));
        return address(provider_contract);
    }
    // @dev close provider
    function closeProvider() public onlyProvider {
        poaResource memory temp_total = providers[msg.sender].getTotalResource();
        poaResource memory temp_left = providers[msg.sender].getLeftResource();
        require(temp_total.cpu_count == temp_left.cpu_count);
        require(temp_total.memory_count == temp_left.memory_count);
        require(temp_total.storage_count == temp_left.storage_count);

        total_all.cpu_count = total_all.cpu_count - temp_total.cpu_count;
        total_all.memory_count = total_all.memory_count - temp_total.memory_count;
        total_all.storage_count = total_all.storage_count - temp_total.storage_count;
        providers[msg.sender].withdrawMargins();
    }
    // @dev calculate margin amount
    function calcProviderAmount(uint256 cpu_count, uint256 memory_count) public view returns (uint256, uint256){
        uint256 temp_mem = memory_count / decimal_memory;
        uint256 temp_cpu = cpu_count / decimal_cpu;
        uint256 calc_temp = temp_cpu;
        if (temp_cpu > temp_mem) {
            calc_temp = temp_mem;
        }
        return (calc_temp * min_value_tobe_provider, calc_temp * max_value_tobe_provider);
    }
    // @dev change order factory
    function changeOrderFactory(address new_order_factory) public onlyAdmin {
        require(new_order_factory != address(0));
        order_factory = new_order_factory;
    }
    // @dev change auditor factory
    function changeAuditorFactory(address new_audit_factory) public onlyAdmin {
        require(new_audit_factory != address(0));
        auditor_factory = new_audit_factory;
    }
    // @dev change admin
    function changeAdmin(address new_admin) public onlyAdmin {
        require(admin != address(0));
        admin = new_admin;
    }
    // @dev get provider contract address
    function getProvideContract(address account) external override view returns (address){
        return address(providers[account]);
    }
    // @dev get provider left resource
    function getProvideResource(address account) external override view returns (poaResource memory){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account, "provider not exist");
        return IProvider(account).getLeftResource();
    }
    // @dev get provider total resource
    function getProvideTotalResource(address account) external override view returns (poaResource memory){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account, "provider not exist");
        return IProvider(account).getTotalResource();
    }
    // @dev change all resource when single provider all resource change
    function changeProviderResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external onlyProvider override {
        if (add) {
            total_all.cpu_count = total_all.cpu_count + cpu_count;
            total_all.memory_count = total_all.memory_count + mem_count;
            total_all.storage_count = total_all.storage_count + storage_count;
        } else {
            total_all.cpu_count = total_all.cpu_count - cpu_count;
            total_all.memory_count = total_all.memory_count - mem_count;
            total_all.storage_count = total_all.storage_count - storage_count;
        }
    }
    // @dev change use resource when single provider use resource change
    function changeProviderUsedResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external override onlyProvider {
        if (add) {
            total_used.cpu_count = total_used.cpu_count + cpu_count;
            total_used.memory_count = total_used.memory_count + mem_count;
            total_used.storage_count = total_used.storage_count + storage_count;
        } else {
            total_used.cpu_count = total_used.cpu_count - cpu_count;
            total_used.memory_count = total_used.memory_count - mem_count;
            total_used.storage_count = total_used.storage_count - storage_count;
        }
    }
    // @dev user consume resource through order
    function consumeResource(address account, uint256 cpu_count, uint256 mem_count, uint256 storage_count) external override nonReentrant {
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender) > 0, "not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).consumeResource(cpu_count, mem_count, storage_count);
    }
    // @dev user recover resource through order
    function recoverResource(address account, uint256 cpu_count, uint256 mem_count, uint256 storage_count) external override nonReentrant {
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender) > 0, "not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).recoverResource(cpu_count, mem_count, storage_count);
    }
    // @dev get provider count
    function getProviderInfoLength() public view returns (uint256){
        return provider_array.length;
    }
    // @dev check provider whether can por
    function whetherCanPOR(address provider_owner) external view returns (bool){
        if (providers[provider_owner] == IProvider(address(0))) {
            return false;
        }
        if (providers[provider_owner].challenge()) {
            return false;
        }
        poaResource memory temp_total = (providers[provider_owner]).getLeftResource();
        (uint256 limit_min,) = calcProviderAmount(temp_total.cpu_count, temp_total.memory_count);
        if (limit_min >= min_value_tobe_provider) {
            return true;
        }
        return false;
    }
    // @dev provider challenge state
    function changeProviderState(address provider_owner, bool whether_start) external onlyValidator {
        if (providers[provider_owner] == IProvider(address(0))) {
            return;
        }
        providers[provider_owner].startChallenge(whether_start);
    }
    // @dev get providers resource info
    function getTotalDetail() external view returns (poaResource memory, poaResource memory){
        return (total_all, total_used);
    }
    // @dev get single provider info
    function getProviderSingle(address _provider_contract) public view returns (providerInfos memory){
        require(address(providers[IProvider(_provider_contract).owner()]) == _provider_contract, "provider_contract error");
        providerInfos memory _providerInfos;
        _providerInfos.info = IProvider(_provider_contract).getDetail();
        _providerInfos.provider_contract = _provider_contract;
        if (auditor_factory != address(0)) {
            _providerInfos.audits = IAuditorFactory(auditor_factory).getProviderAuditors(_provider_contract);
        }
        _providerInfos.margin_amount = _provider_contract.balance;
        return _providerInfos;
    }
    // @dev get providers info
    function getProviderInfo(uint256 start, uint256 limit) public view returns (providerInfos[] memory){
        if (provider_array.length == 0) {
            providerInfos[] memory _providerInfos_empty;
            return _providerInfos_empty;
        }
        uint256 _limit = limit;
        if (limit == 0) {
            require(start == 0, "must start with zero");
            _limit = provider_array.length;
        }
        require(start < provider_array.length, "start>provider_array.length");
        uint256 _count = provider_array.length - start;
        if (provider_array.length - start > _limit) {
            _count = _limit;
        }
        providerInfos[] memory _providerInfos = new providerInfos[](_count);
        for (uint256 i = 0; i < _count; i++) {
            _providerInfos[i].info = IProvider(provider_array[i]).getDetail();
            _providerInfos[i].provider_contract = address(provider_array[i]);
            if (auditor_factory != address(0)) {
                _providerInfos[i].audits = IAuditorFactory(auditor_factory).getProviderAuditors(address(provider_array[i]));
            }
            _providerInfos[i].margin_amount = address(provider_array[i]).balance;
        }
        return _providerInfos;
    }
    // @dev remove provider from punish list
    function removeProviderPunishList(address provider) external onlyProvider {
        SortLinkedList.List storage _list = provider_punish_pools;
        _list.removeRanking(providers[provider]);
    }
    // @dev remove provider from punish list
    function removePunishList(address provider) external onlyValidator {
        SortLinkedList.List storage _list = provider_punish_pools;
        _list.removeRanking(providers[provider]);
        providers[provider].removePunish();
    }
    // @dev try to punish provider
    function tryPunish(address new_provider)
    external {
        if (new_provider != address(0)) {
            //TODO for test
            require(msg.sender == val_factory, "only val factory add new punish provider");
            require(providers[new_provider] != IProvider(address(0)), "ProviderFactory: not validator");
            poaResource memory temp_total = (providers[new_provider]).getTotalResource();
            (uint256 limit_min,) = calcProviderAmount(temp_total.cpu_count, temp_total.memory_count);
            if (limit_min != 0) {
                SortLinkedList.List storage _list = provider_punish_pools;
                _list.improveRanking(providers[new_provider]);
            }
        }

        SortLinkedList.List storage _providerPunishPool = provider_punish_pools;
        IProvider[] memory tempProvider = new IProvider[](_providerPunishPool.length);
        uint256 index = 0;
        IProvider _cur = _providerPunishPool.head;
        while (_cur != IProvider(address(0))) {
            //_cur.punish();
            tempProvider[index] = _cur;
            _cur = _providerPunishPool.next[_cur];
            index = index + 1;
        }
        for (uint256 i = 0; i < tempProvider.length; i++) {
            tempProvider[i].punish();
        }
    }
    // @dev get punish amount
    function getPunishAmount(uint256 punish_amount) external override view returns (uint256){
        uint256 temp_punish = punish_amount;
        poaResource memory temp_total = IProvider(msg.sender).getTotalResource();
        (uint256 limit_min,) = calcProviderAmount(temp_total.cpu_count, temp_total.memory_count);
        if (punish_amount < limit_min) {
            temp_punish = limit_min;
        }
        return temp_punish * punish_percent / punish_all_percent;
    }

    function getPunishLength() external view returns (uint256){
        return uint256(provider_punish_pools.length);
    }

    function getPunishAddress() external view returns (address[] memory){
        address[] memory ret = new address[](provider_punish_pools.length);
        SortLinkedList.List storage _providerPunish = provider_punish_pools;
        IProvider _cur = _providerPunish.head;
        uint256 index = 0;
        while (_cur != IProvider(address(0))) {
            ret[index] = _cur.owner();
            _cur = _providerPunish.next[_cur];
            index = index + 1;
        }
        return ret;
    }
}
