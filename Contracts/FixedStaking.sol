// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import './interfaces/IAutoBSW.sol';

contract FixedStaking is Initializable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    struct Pool {
        IERC20Upgradeable token;
        uint32 endDay;
        uint32 dayPercent; //one day percent in Base 10000
        uint16 lockPeriod; //lock period in days
        uint16 withdrawalFee; // early withdrawal fee in base 10000
        uint128 maxDeposit;
        uint128 minDeposit;
        uint128 holderPoolMinAmount;
        uint128 totalDeposited;
        uint128 maxPoolAmount;
        bool depositEnabled;
    }

    struct UserInfo {
        uint128 userDeposit; //User deposit on pool
        uint128 accrueInterest; //User accrue interest
        uint32 lastDayAction;
    }

    struct InfoFront {
        Pool pool;
        UserInfo userInfo;
    }

    Pool[] public pools;
    IAutoBSW public autoBSW;
    address public treasury;
    mapping(address => mapping(uint => UserInfo)) public userInfo; //User info storage: user address => poolId => UserInfo struct
    mapping(uint32 => mapping(address => uint128)) public pendingWithdraw; //Pending withdraw day => token => amount
    mapping(address => mapping(address => uint32)) public userPendingWithdraw; //User pending withdraw flag user address => token => day

    event Deposit(address indexed user, uint128 amount, address indexed token);
    event Withdraw(address indexed user, address token, uint128 pendingInterest, uint128 userDeposit, uint128 fee);
    event PendingWithdraw(address indexed user, address indexed token, uint128 accumAmount);
    event PoolChangeState(uint poolIndex, bool state);
    event PoolChanged(uint poolIndex);
    event Harvest(address indexed user, address token, uint128 amount);
    event TreasuryWithdraw(address indexed token, uint amount);
    //Initialize function --------------------------------------------------------------------------------------------

    function initialize(address _treasury, IAutoBSW _autoBSW) public initializer {
        __AccessControl_init_unchained();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TREASURY_ROLE, _treasury);
        treasury = _treasury;
        autoBSW = _autoBSW;
    }

    //Modifiers ------------------------------------------------------------------------------------------------------

    modifier notContract() {
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        require(msg.sender.code.length == 0, "Contract not allowed");
        _;
    }

    //External functions ---------------------------------------------------------------------------------------------

    function setAutoBSW(IAutoBSW _autoBSW) external onlyRole(DEFAULT_ADMIN_ROLE){
        require(address(_autoBSW) != address(0), "Cant be zero address");
        autoBSW = _autoBSW;
    }

    function addPool(Pool calldata _pool) external onlyRole(DEFAULT_ADMIN_ROLE){
        require(address(_pool.token) != address(0), "Cant be zero address");
        pools.push(_pool);
    }

    function changePool(uint _poolIndex, Pool calldata _pool) external onlyRole(DEFAULT_ADMIN_ROLE){
        require(_poolIndex < pools.length, "Index out of bound");
        uint128 _totalDeposited = pools[_poolIndex].totalDeposited;
        IERC20Upgradeable _token = pools[_poolIndex].token;
        pools[_poolIndex] = _pool;
        pools[_poolIndex].totalDeposited = _totalDeposited; //Save total deposited when upgrade pool
        pools[_poolIndex].token = _token; //Cant change token when pool started
        emit PoolChanged(_poolIndex);
    }

    function setPoolState(uint _poolIndex, bool _state) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_poolIndex < pools.length, "Index out of bound");
        pools[_poolIndex].depositEnabled = _state;
        emit PoolChangeState(_poolIndex, _state);
    }

    function setPoolEndDay(uint _poolIndex, uint32 _endDay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_poolIndex < pools.length, "Index out of bound");
        pools[_poolIndex].endDay = _endDay;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    //Public functions -----------------------------------------------------------------------------------------------

    function getCurrentDay() public view returns(uint32 currentDay){
        currentDay = uint32(block.timestamp / 86400);
    }

    function getHolderPoolAmount(address _user) public view returns(uint holderPoolAmount){
        holderPoolAmount = autoBSW.balanceOf() * autoBSW.userInfo(_user).shares / autoBSW.totalShares();
    }

    function getUserInfo(address _user) public view returns(InfoFront[] memory info, uint holderPoolAmount){
        info = new InfoFront[](pools.length);
        uint32 currentDay = getCurrentDay();
        for(uint i = 0; i < info.length; i++){
            info[i].pool = pools[i];
            info[i].userInfo = userInfo[_user][i];

            uint32 multiplier = getMultiplier(info[i].userInfo.lastDayAction, info[i].pool.endDay);
            info[i].userInfo.accrueInterest += info[i].userInfo.userDeposit == 0 && info[i].userInfo.lastDayAction >= currentDay ? 0 :
            (info[i].userInfo.userDeposit * info[i].pool.dayPercent / 10000) * multiplier;
        }
        holderPoolAmount = _user == address(0) ? 0 : getHolderPoolAmount(_user);
    }

    function deposit(uint _poolIndex, uint128 _amount) public nonReentrant whenNotPaused notContract {
        require(_poolIndex < pools.length, "Index out of bound");
        Pool memory _pool = pools[_poolIndex];
        require(_pool.holderPoolMinAmount <= getHolderPoolAmount(msg.sender), "Need more stake in holder pool");
        UserInfo storage _userInfo = userInfo[msg.sender][_poolIndex];
        uint32 currentDay = getCurrentDay();
        require(_pool.depositEnabled && currentDay < _pool.endDay, "Deposit on pool is disabled");
        require(_userInfo.userDeposit + _amount >= _pool.minDeposit &&
                _userInfo.userDeposit + _amount <= _pool.maxDeposit &&
                _pool.totalDeposited + _amount <= _pool.maxPoolAmount, "Amount over pool limits");
        _pool.token.safeTransferFrom(msg.sender, address(this), _amount);
        uint32 multiplier = getMultiplier(_userInfo.lastDayAction, _pool.endDay);
        _userInfo.accrueInterest += _userInfo.userDeposit == 0 && _userInfo.lastDayAction >= currentDay ? 0 :
            (_userInfo.userDeposit * _pool.dayPercent / 10000) * multiplier;
        _userInfo.lastDayAction = currentDay;
        _userInfo.userDeposit += _amount;
        pools[_poolIndex].totalDeposited += _amount;
        emit Deposit(msg.sender, _amount, address(_pool.token));
    }

    function withdraw(uint _poolIndex) public nonReentrant whenNotPaused notContract {
        Pool memory _pool = pools[_poolIndex];
        UserInfo storage _userInfo = userInfo[msg.sender][_poolIndex];
        require(_userInfo.userDeposit > 0, "User has zero deposit");
        uint128 pendingInterest;
        uint128 fee;
        uint32 currentDay = getCurrentDay();
        uint32 multiplier = getMultiplier(_userInfo.lastDayAction, _pool.endDay);
        pendingInterest = _userInfo.accrueInterest +
            (_userInfo.userDeposit * _pool.dayPercent / 10000) * multiplier;
        if(currentDay - _userInfo.lastDayAction <= _pool.lockPeriod && currentDay < _pool.endDay){
            fee = _userInfo.userDeposit * _pool.withdrawalFee / 10000 + pendingInterest;
        }

        uint128 accumAmount = _userInfo.userDeposit + pendingInterest;
        if(_pool.token.balanceOf(address(this)) < accumAmount){
            if(userPendingWithdraw[msg.sender][address(_pool.token)] != currentDay){
                pendingWithdraw[currentDay][address(_pool.token)] += accumAmount;
                userPendingWithdraw[msg.sender][address(_pool.token)] = currentDay;
                emit PendingWithdraw(msg.sender, address(_pool.token), accumAmount);
            }
            return;
        } else {
            pools[_poolIndex].totalDeposited -= _userInfo.userDeposit;
            emit Withdraw(msg.sender, address(_pool.token), pendingInterest, _userInfo.userDeposit, fee);
            _userInfo.accrueInterest = 0;
            _userInfo.userDeposit = 0;
            if(fee > 0) _pool.token.safeTransfer(treasury, fee);
            _pool.token.safeTransfer(msg.sender, accumAmount - fee);
        }
    }

    function harvest(uint _poolIndex) public nonReentrant whenNotPaused notContract {
        Pool memory _pool = pools[_poolIndex];
        UserInfo storage _userInfo = userInfo[msg.sender][_poolIndex];
        uint32 currentDay = getCurrentDay();
        uint32 multiplier = getMultiplier(_userInfo.lastDayAction, _pool.endDay);
        require(currentDay - _userInfo.lastDayAction > _pool.lockPeriod || currentDay >= _pool.endDay, "Lock period not finished");
        uint128 pendingAmount = _userInfo.accrueInterest + (_userInfo.userDeposit * _pool.dayPercent / 10000) * multiplier;
        if(_pool.token.balanceOf(address(this)) < pendingAmount){
            if(userPendingWithdraw[msg.sender][address(_pool.token)] != currentDay){
                pendingWithdraw[currentDay][address(_pool.token)] += pendingAmount;
                userPendingWithdraw[msg.sender][address(_pool.token)] = currentDay;
                emit PendingWithdraw(msg.sender, address(_pool.token), pendingAmount);
            }
            return;
        } else {
            _userInfo.accrueInterest = 0;
            _userInfo.lastDayAction = currentDay;
            _pool.token.safeTransfer(msg.sender, pendingAmount);
            emit Harvest(msg.sender, address(_pool.token), pendingAmount);
        }
    }

    function withdrawToken(IERC20Upgradeable _token, uint _amount) public onlyRole(TREASURY_ROLE) {
        require(address(_token) != address(0), "Cant be zero address");
        _token.safeTransfer(treasury, _amount);
        emit TreasuryWithdraw(address(_token), _amount);
    }

    //Internal functions ---------------------------------------------------------------------------------------------

    function getMultiplier(uint32 _lasDayAction, uint32 _poolEndDay) internal view returns (uint32 multiplier) {
        uint32 currentDay = getCurrentDay();
        if(currentDay <= _lasDayAction){
            multiplier = 0;
        } else if(_poolEndDay > currentDay){
            multiplier = currentDay - _lasDayAction;
        } else {
            multiplier = _poolEndDay > _lasDayAction ? _poolEndDay - _lasDayAction : 0;
        }
    }

}
