// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ReentrancyGuard.sol";
import "./InterfaceProvider.sol";
import "./InterfaceAuditor.sol";
import "./InterfaceOrderFactory.sol";
import "./SortList.sol";

contract Provider is IProvider, ReentrancyGuard {
    poaResource public total;
    poaResource public used;
    poaResource public lock;
    bool public override challenge;
    ProviderState public state;
    address public override owner;
    string public region;

    uint256 public provider_first_margin_time;
    uint256 public override last_margin_time;
    uint256 public last_challenge_time;

    uint256 public margin_block;
    uint256 public punish_start_time;
    uint256 public punish_start_margin_amount;
    uint256 public last_punish_time;
    string  public override info;

    event Punish(address indexed, uint256 indexed, uint256 indexed);
    event MarginAdd(address indexed, uint256 indexed, uint256 indexed);
    event MarginWithdraw(address indexed, uint256 indexed);
    event StateChange(address indexed, uint256 indexed);
    event ChallengeStateChange(address indexed, bool);

    IProviderFactory provider_factory;
    constructor(uint256 cpu_count,
        uint256 mem_count,
        uint256 storage_count,
        address _owner,
        string memory _region,
        string memory provider_info){
        provider_factory = IProviderFactory(msg.sender);
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
    }
    function getLeftResource() public view override returns (poaResource memory){
        poaResource memory left;
        left.cpu_count = total.cpu_count - used.cpu_count;
        left.memory_count = total.memory_count - used.memory_count;
        left.storage_count = total.storage_count - used.storage_count;
        return left;
    }

    function withdrawMargin() external override onlyFactory {
        uint256 balance_before = address(this).balance;
        sendValue(payable(owner), address(this).balance);
        emit MarginWithdraw(owner, balance_before);
    }

    function removePunish() external override onlyFactory {
        punish_start_time = 0;
        last_punish_time = 0;
        if (state == ProviderState.Punish || state == ProviderState.Pause) {
            state = ProviderState.Running;
            emit StateChange(owner, uint256(state));
        }
    }

    function punish() external override onlyFactory {
        if (block.timestamp - punish_start_time > provider_factory.punish_start_limit() && punish_start_time != 0) {

            if (block.timestamp - last_punish_time > provider_factory.punish_interval()) {
                uint256 PunishAmount = (provider_factory).getPunishAmount(punish_start_margin_amount);
                uint256 _punishAmount = address(this).balance >= PunishAmount ? PunishAmount : address(this).balance;
                if (_punishAmount > 0) {
                    sendValue(payable(provider_factory.punish_address()), _punishAmount);
                    emit Punish(owner, _punishAmount, address(this).balance);
                }
                last_punish_time = block.timestamp;
            }
            if (address(this).balance == 0) {
                state = ProviderState.Pause;
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

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");
        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success,) = recipient.call{value : amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    receive() external payable onlyFactory {
        margin_block = block.number;
        last_margin_time = block.timestamp;
        if (state == ProviderState.Pause) {
            state = ProviderState.Punish;
            emit StateChange(owner, uint256(state));
        }
        emit MarginAdd(owner, msg.value, address(this).balance);
    }

    event ProviderResourceChange(address);
    modifier onlyFactory(){
        require(msg.sender == address(provider_factory), "factory only");
        _;
    }
    modifier onlyOwner{
        require(msg.sender == owner, "owner only");
        _;
    }
    modifier onlyNotStop{
        require(state != ProviderState.Stop, "only not stop");
        _;
    }
    function changeProviderInfo(string memory new_info) public onlyOwner {
        info = new_info;
    }

    function changeRegion(string memory _new_region) public onlyOwner {
        region = _new_region;
    }

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
        return ret;
    }


    function getTotalResource() external override view returns (poaResource memory){
        return total;
    }

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

    function reduceResource(uint256 cpu_count, uint256 memory_count, uint256 storage_count) external onlyOwner onlyNotStop {
        poaResource memory _left;
        _left.cpu_count = total.cpu_count - used.cpu_count;
        _left.memory_count = total.memory_count - used.memory_count;
        _left.storage_count = total.storage_count - used.storage_count;

        require(_left.cpu_count >= cpu_count && _left.memory_count >= memory_count && _left.storage_count >= storage_count, "Provider: dont have enough resource to reduce");
        provider_factory.changeProviderResource(total.cpu_count, total.memory_count, total.storage_count, false);
        total.cpu_count = total.cpu_count - cpu_count;
        total.memory_count = total.memory_count - memory_count;
        total.storage_count = total.storage_count - storage_count;
        provider_factory.changeProviderResource(used.cpu_count, used.memory_count, used.storage_count, true);
        emit ProviderResourceChange(address(this));
    }

    function updateResource(uint256 new_cpu_count, uint256 new_mem_count, uint256 new_sto_count) external onlyOwner onlyNotStop {
        provider_factory.changeProviderResource(total.cpu_count, total.memory_count, total.storage_count, false);
        total.cpu_count = used.cpu_count + new_cpu_count;
        total.memory_count = used.memory_count + new_mem_count;
        total.storage_count = used.storage_count + new_sto_count;
        provider_factory.changeProviderResource(total.cpu_count, total.memory_count, total.storage_count, true);
        emit ProviderResourceChange(address(this));
    }

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

    uint256 public provider_lock_time;
    uint256 public min_value_tobe_provider;
    uint256 public max_value_tobe_provider;

    uint256 public decimal_cpu;
    uint256 public decimal_memory;

    uint256 public punish_percent;
    uint256 public punish_all_percent;
    uint256 public override punish_start_limit;
    uint256 public override punish_interval;
    address public override punish_address;

    bool public initialized;

    poaResource public total_all;
    poaResource public total_used;
    mapping(address => IProvider) public providers;
    address public constant val_factory = address(0x000000000000000000000000000000000000c002);
    //mapping(address => uint256) public provider_pledge;
    IProvider[] provider_array;
    address public order_factory;
    address public admin;
    address public auditor_factory;
    SortLinkedList.List provider_punish_pools;

    struct providerInfos {
        address provider_contract;
        providerInfo info;
        uint256 margin_amount;
        address[] audits;
    }

    event ProviderCreate(address);

    modifier onlyAdmin() {
        require(msg.sender == admin, "admin only");
        _;
    }
    modifier onlyMiner() {
        require(msg.sender == block.coinbase, "Miner only");
        _;
    }
    modifier onlyProvider(){
        require(providers[IProvider(msg.sender).owner()] != IProvider(address(0)), "provider contract only");
        _;
    }
    modifier onlyNotInitialize(){
        require(!initialized, "only not initialize");
        _;
    }
    modifier onlyNotProvider(){
        require(providers[msg.sender] == IProvider(address(0)), "only not provider");
        _;
    }
    modifier onlyValidator(){
        require(msg.sender == val_factory);
        _;
    }
    function changePunishAddress(address _punish_address) public onlyAdmin {
        punish_address = _punish_address;
    }

    function changeProviderLockTime(uint256 _lock_time) public onlyAdmin {
        provider_lock_time = _lock_time;
    }

    function changePunishPercent(uint256 _new_punish_percent, uint256 _new_punish_all_percent) external onlyAdmin {
        require(_new_punish_percent < _new_punish_all_percent, "percent error");
        punish_percent = _new_punish_percent;
        punish_all_percent = _new_punish_all_percent;
    }

    function changeProviderLimit(uint256 _new_min, uint256 _new_max) public onlyAdmin {
        min_value_tobe_provider = _new_min;
        max_value_tobe_provider = _new_max;
    }

    function changePunishParam(uint256 _new_punish_start_limit, uint256 _new_punish_interval) public onlyAdmin {
        punish_start_limit = _new_punish_start_limit;
        punish_interval = _new_punish_interval;
    }

    function changeDecimal(uint256 new_cpu_decimal, uint256 new_memory_decimal) external onlyAdmin {
        decimal_cpu = new_cpu_decimal;
        decimal_memory = new_memory_decimal;
    }

    function addMargin() public payable {
        require(providers[msg.sender] != IProvider(address(0)), "only provider owner");
        poaResource memory temp_total = providers[msg.sender].getTotalResource();
        (uint256 limit_min,uint256 limit_max) = calcProviderAmount(temp_total.cpu_count, temp_total.memory_count);
        require(address(providers[msg.sender]).balance + msg.value >= limit_min && address(providers[msg.sender]).balance + msg.value <= limit_max, "pledge money range error");
        //provider_pledge[msg.sender] =provider_pledge[msg.sender] + msg.value;
        (bool sent,) = (address(providers[msg.sender])).call{value : msg.value}("");
        require(sent, "add Margin fail");
    }

    function withdrawMargin() public {
        require(providers[msg.sender] != IProvider(address(0)), "only provider owner");
        require(providers[msg.sender].last_margin_time() + provider_lock_time < block.timestamp, "time not enough");
        providers[msg.sender].withdrawMargin();
    }

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

    function closeProvider() public onlyProvider {
        poaResource memory temp_total = providers[msg.sender].getTotalResource();
        poaResource memory temp_left = providers[msg.sender].getLeftResource();
        require(temp_total.cpu_count == temp_left.cpu_count);
        require(temp_total.memory_count == temp_left.memory_count);
        require(temp_total.storage_count == temp_left.storage_count);

        total_all.cpu_count = total_all.cpu_count - temp_total.cpu_count;
        total_all.memory_count = total_all.memory_count - temp_total.memory_count;
        total_all.storage_count = total_all.storage_count - temp_total.storage_count;
        providers[msg.sender].withdrawMargin();
    }

    function calcProviderAmount(uint256 cpu_count, uint256 memory_count) public view returns (uint256, uint256){
        uint256 temp_mem = memory_count / decimal_memory;
        uint256 temp_cpu = cpu_count / decimal_cpu;
        uint256 calc_temp = temp_cpu;
        if (temp_cpu > temp_mem) {
            calc_temp = temp_mem;
        }
        return (calc_temp * min_value_tobe_provider, calc_temp * max_value_tobe_provider);
    }

    function changeOrderFactory(address new_order_factory) public onlyAdmin {
        require(new_order_factory != address(0));
        order_factory = new_order_factory;
    }

    function changeAuditorFactory(address new_audit_factory) public onlyAdmin {
        require(new_audit_factory != address(0));
        auditor_factory = new_audit_factory;
    }

    function changeAdmin(address new_admin) public onlyAdmin {
        require(admin != address(0));
        admin = new_admin;
    }

    function getProvideContract(address account) external override view returns (address){
        return address(providers[account]);
    }

    function getProvideResource(address account) external override view returns (poaResource memory){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account, "provider not exist");
        return IProvider(account).getLeftResource();
    }

    function getProvideTotalResource(address account) external override view returns (poaResource memory){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account, "provider not exist");
        return IProvider(account).getTotalResource();
    }

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

    function consumeResource(address account, uint256 cpu_count, uint256 mem_count, uint256 storage_count) external override nonReentrant {
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender) > 0, "not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).consumeResource(cpu_count, mem_count, storage_count);
    }

    function recoverResource(address account, uint256 cpu_count, uint256 mem_count, uint256 storage_count) external override nonReentrant {
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender) > 0, "not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).recoverResource(cpu_count, mem_count, storage_count);
    }

    function getProviderInfoLength() public view returns (uint256){
        return provider_array.length;
    }

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

    function changeProviderState(address provider_owner, bool whether_start) external onlyValidator {
        if (providers[provider_owner] == IProvider(address(0))) {
            return;
        }
        providers[provider_owner].startChallenge(whether_start);
    }

    function getTotalDetail() external view returns (poaResource memory, poaResource memory){
        return (total_all, total_used);
    }

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

    function removePunishList(address provider) onlyValidator external {
        SortLinkedList.List storage _list = provider_punish_pools;
        _list.removeRanking(providers[provider]);
        providers[provider].removePunish();
    }

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
        IProvider _cur = _providerPunishPool.head;
        while (_cur != IProvider(address(0))) {
            _cur.punish();
            _cur = _providerPunishPool.next[_cur];
        }
    }

    function getPunishAmount(uint256 punish_amount) external override view returns (uint256){
        uint256 temp_punish = punish_amount;
        poaResource memory temp_total = IProvider(msg.sender).getTotalResource();
        (uint256 limit_min,) = calcProviderAmount(temp_total.cpu_count, temp_total.memory_count);
        if (punish_amount < limit_min) {
            temp_punish = limit_min;
        }
        return temp_punish * punish_percent / punish_all_percent;
    }

}
