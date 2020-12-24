pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Math.sol";
import "./utils/ReentrancyGuard.sol";

// V2YtVG9Q611sxG388a7GW4ChQwxbbFpWYx stake地址
// 0x1100000000000000000000000000000000000001
// cd48d28ba50626523cfbd3076fe0045211bfff1c 合约地址
// VKiSm7obsDwaFr6FxzR87w6KJUUYrE25pa 合约地址
// 0x267ec0079043b43930a1d671fb98fd19fdcaf449 stake 节点地址
// 0xd7dab89a06c538ee078af2008ffd05ff7c38966a stake 2 节点地址
// 82e26fa89f2461932ab09a0ec6625e06f02d5a96 对应的 miningAddress 地址？
// V2Tbp525fpnBRiSt4iPxXkxMyf5ZYuW1Aa validator 地址
// 0x1000000000000000000000000000000000000001

// 部署的合约地址 0x16bdBc6ef829E1CB0A3c01D58ef91Fcf4a03c0Bd

contract SVLX is ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private pools;
    using Math for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string public name = "Staking Velas";
    string public symbol = "SVLX";
    uint8 public decimals = 18;

    /// @notice stake 合约地址
    address public stakingAuRa;

    address public validatorSetContract;

    /// @notice 合约管理员地址
    address public admin;

    /// @notice 预备管理员地址
    address public proposedAdmin;

    /// @notice 节点地址
    // address[] public pools;

    /// @notice 下一次存款节点索引
    uint256 public nextIndex;

    /// @notice svlx 代币生成量
    uint public _totalSupply;

    uint256 public index = 0;
    uint256 public bal = 0;
    mapping(address => uint256) public claimable;
    mapping(address => uint256) public supplyIndex;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    /// @notice 事件：claim 之前 order 过的币
    /// @param poolAddress 节点地址
    /// @param amount 数量
    event ClaimOrderedWithdraw(address indexed poolAddress, uint256 amount);

    /// @notice 事件：在节点中取出币
    /// @param poolAddress 节点地址
    /// @param amount 数量
    event PoolWithdraw(address indexed poolAddress, uint256 amount);

    /// @notice 事件：order 币
    /// @param poolAddress 节点地址
    /// @param amount 数量
    event OrderWithdraw(address indexed poolAddress, int256 amount);

    /// @notice 事件：设置 staking 地址
    /// @param oldStakingAuRa 旧地址
    /// @param newStakingAuRa 新地址
    event SetStakingAuRa(address oldStakingAuRa, address newStakingAuRa);

    /// @notice 事件：设置 validatorSetContract 地址
    /// @param oldValidatorSetContract 旧地址
    /// @param newValidatorSetContract 新地址
    event SetValidatorSetContract(
        address oldValidatorSetContract,
        address newValidatorSetContract
    );

    /// @notice 事件：设置预备管理员
    /// @param proposedAdmin 预备管理员地址
    event SetProposedAdmin(address proposedAdmin);

    /// @notice 事件：claim 管理员
    /// @param oldAdmin 旧管理员地址
    /// @param newAdmin 新管理员地址
    event ClaimAdmin(address oldAdmin, address newAdmin);

    /// @notice 事件：设置 pool
    /// @param index 节点索引
    /// @param oldPool 旧节点地址
    /// @param newPool 新节点地址
    event SetPool(uint256 index, address oldPool, address newPool);

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address _stakingAuRa) public {
        admin = msg.sender;
        nextIndex = 0;
        stakingAuRa = _stakingAuRa;
        validatorSetContract = IStakingAuRa(stakingAuRa).validatorSetContract();
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "Admin required");
        _;
    }

    /// @notice 存款
    function deposit() public payable nonReentrant {
        // 存入直接 stake
        require(msg.value > 0, "Invalid value");

        address currentPool = pools.at(nextIndex);
        // 轮询节点 deposit
        nextIndex = (nextIndex + 1) % pools.length();
        _mint(msg.sender, msg.value);

        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        uint256 minStake = auRa.delegatorMinStake();
        // 若用户存款数量大于最低质押数量，或者当前节点质押数量大于0，说明用户可以正常质押
        if (
            msg.value >= minStake ||
            auRa.stakeAmount(currentPool, address(this)) > 0
        ) {
            IStakingAuRa(stakingAuRa).stake{value: msg.value}(
                currentPool,
                msg.value
            );
        } else if (msg.value + calcBalance() >= minStake) {
            IStakingAuRa(stakingAuRa).stake{value: msg.value}(
                currentPool,
                msg.value + calcBalance()
            );
        }
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice 取款
    function withdraw(uint256 wad) public nonReentrant returns (uint256) {
        require(balanceOf[msg.sender] >= wad, "svlx: insufficient balance");
        uint256 currentBalance = calcBalance();

        EnumerableSet.AddressSet storage _pools = pools;
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        IValidatorSetAuRa validatorSet =
            IValidatorSetAuRa(validatorSetContract);
        if (currentBalance < wad) {
            // claim 之前已经 order 过的数量
            // 既然已经 order 过，留在节点中也没用，全部 claim
            for (uint256 i = 0; i < pools.length(); ++i) {
                if (_isWithdrawAllowed(_pools.at(i))) {
                    claimOrderedWithdraw(_pools.at(i));
                }
            }
        }
        for (uint256 i = 0; i < pools.length(); ++i) {
            // 每次循环时判断是否合约中的余额是否充足，如果充足，那么不需要再进行取款操作，直接跳出
            currentBalance = calcBalance();
            uint256 needToWithdraw =
                wad > currentBalance ? wad.sub(currentBalance) : 0;
            if (needToWithdraw == 0) {
                break;
            }
            if (_isWithdrawAllowed(pools.at(i))) {
                // max 的值，只有两种情况
                // 1. stakeAmount map 里面的数，即质押的数量（节点不是验证者）
                // 2. 当前 epoch 中存进去的数（节点是验证者）
                uint256 maxAllowed =
                    auRa.maxWithdrawAllowed(pools.at(i), address(this));
                // 锁仓数量
                uint256 stakeAmount =
                    auRa.stakeAmount(pools.at(i), address(this));
                uint256 maxWithdrawal = maxAllowed.min(stakeAmount);
                uint256 delegatorMinStake = auRa.delegatorMinStake();
                if (maxWithdrawal > 0) {
                    // threshold 为不取完的情况下，可取出的最大值
                    uint256 threshold = stakeAmount.sub(delegatorMinStake);
                    if (threshold > needToWithdraw) {
                        auRa.withdraw(
                            pools.at(i),
                            needToWithdraw.min(maxWithdrawal)
                        );
                        emit PoolWithdraw(
                            pools.at(i),
                            needToWithdraw.min(maxWithdrawal)
                        );
                    } else {
                        auRa.withdraw(pools.at(i), maxWithdrawal);
                        emit PoolWithdraw(pools.at(i), maxWithdrawal);
                    }
                }
            }
        }
        currentBalance = calcBalance();
        // tempBalance 用于累加 orderWithdraw 的数量
        // 由于 order 过程并不会增加本合约的实际余额，因此使用此变量
        uint256 tempBalance = currentBalance;
        for (uint256 i = 0; i < pools.length(); ++i) {
            if (tempBalance > wad || currentBalance > wad) {
                break;
            }
            if (_isWithdrawAllowed(pools.at(i))) {
                uint256 maxOrderWithdrawal =
                    auRa.maxWithdrawOrderAllowed(pools.at(i), address(this));
                address _miningAddress =
                    validatorSet.miningByStakingAddress(pools.at(i));

                if (
                    validatorSet.isValidatorOrPending(_miningAddress) &&
                    maxOrderWithdrawal > 0
                ) {
                    tempBalance += maxOrderWithdrawal;
                    auRa.orderWithdraw(pools.at(i), int256(maxOrderWithdrawal));
                }
            }
        }
        uint256 withdrawAmount = wad.min(calcBalance());
        _burn(msg.sender, withdrawAmount);
        msg.sender.transfer(withdrawAmount);
        emit Withdrawal(msg.sender, withdrawAmount);

        return withdrawAmount;
    }

    /// @notice 查询可直接从合约中取出的数量
    function withdrawableAmount() public view returns (uint256 res) {
        EnumerableSet.AddressSet storage _pools = pools;
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        res = calcBalance();
        for (uint256 i = 0; i < pools.length(); ++i) {
            if (_isWithdrawAllowed(_pools.at(i))) {
                res = res.add(claimableOrderedAmount(_pools.at(i)));
            }
        }

        for (uint256 i = 0; i < pools.length(); ++i) {
            if (_isWithdrawAllowed(pools.at(i))) {
                uint256 maxAllowed =
                    auRa.maxWithdrawAllowed(pools.at(i), address(this));
                // 锁仓数量
                uint256 stakeAmount =
                    auRa.stakeAmount(pools.at(i), address(this));
                res = res.add(maxAllowed.min(stakeAmount));
            }
        }
    }

    /// @notice 查询已经像 VELAS 节点申请取出 VLX 的数量，以及到期可取回的区块
    // 返回值 _pools 节点列表
    // 返回值 _amount 节点对应的 order 的数量
    // 返回值 _claimableBlock 可以取出的区块
    function orderedAmount()
        public
        view
        returns (
            address[] memory _pools,
            uint256[] memory _amount,
            uint256[] memory _claimableBlock
        )
    {
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        uint256 stakingEpoch = auRa.stakingEpoch();

        uint256 length = pools.length();

        _pools = new address[](length);
        _amount = new uint256[](length);
        _claimableBlock = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            uint256 claimAmount =
                auRa.orderedWithdrawAmount(pools.at(i), address(this));
            _pools[i] = pools.at(i);
            _amount[i] = claimAmount;

            // 如果是在当前 epoch order 的数量，在当前 epoch 结束后的下一个区块可以取出
            // 如果直接可以取出，返回0
            if (
                stakingEpoch ==
                auRa.orderWithdrawEpoch(pools.at(i), address(this)) &&
                claimAmount > 0
            ) {
                _claimableBlock[i] = auRa.stakingEpochEndBlock() + 1;
            }
        }
    }

    /// @notice 每个节点可以 claim 的数量
    function claimableOrderedAmount(address poolAddress)
        internal
        view
        returns (uint256)
    {
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        uint256 stakingEpoch = auRa.stakingEpoch();
        uint256 claimAmount =
            auRa.orderedWithdrawAmount(poolAddress, address(this));
        if (
            stakingEpoch >
            auRa.orderWithdrawEpoch(poolAddress, address(this)) &&
            claimAmount > 0
        ) {
            return claimAmount;
        }
        return 0;
    }

    /// @notice claim 之前 order 过的数量
    function claimOrderedWithdraw(address poolAddress)
        internal
        returns (uint256)
    {
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        uint256 stakingEpoch = auRa.stakingEpoch();
        uint256 claimAmount =
            auRa.orderedWithdrawAmount(poolAddress, address(this));
        if (
            stakingEpoch >
            auRa.orderWithdrawEpoch(poolAddress, address(this)) &&
            claimAmount > 0
        ) {
            auRa.claimOrderedWithdraw(poolAddress);
            emit ClaimOrderedWithdraw(poolAddress, claimAmount);
            return claimAmount;
        }
        return 0;
    }

    /// @notice 是否可以取款
    function _isWithdrawAllowed(address poolAddress)
        internal
        view
        returns (bool)
    {
        address _miningAddress =
            IValidatorSetAuRa(validatorSetContract).miningByStakingAddress(
                poolAddress
            );
        if (
            IValidatorSetAuRa(validatorSetContract).areDelegatorsBanned(
                _miningAddress
            )
        ) {
            // The delegator cannot withdraw from the banned validator pool until the ban is expired
            return false;
        }

        if (!IStakingAuRa(stakingAuRa).areStakeAndWithdrawAllowed()) {
            return false;
        }

        return true;
    }

    /// @notice 获取总质押数量
    function getAllStaked() public view returns (uint256 res) {
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        for (uint256 i = 0; i < pools.length(); ++i) {
            res = res.add(auRa.stakeAmount(pools.at(i), address(this)));
        }
    }

    /// @notice 获取每个节点质押数量（所有节点，包含质押数量大于以及等于0的节点）
    function getPoolsStaked()
        public
        view
        returns (address[] memory pool, uint256[] memory stake)
    {
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        uint256 length = pools.length();
        pool = new address[](length);
        stake = new uint256[](length);
        for (uint256 i = 0; i < pools.length(); ++i) {
            pool[i] = pools.at(i);
            stake[i] = auRa.stakeAmount(pools.at(i), address(this));
        }
    }

    // 获取当前抵押的 stake 节点列表（只包含质押数量大于0的节点）
    function getStakedPools() public view returns (address[] memory pool) {
        uint256 stakePoolsCount = 0;
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        for (uint256 i = 0; i < pools.length(); ++i) {
            if (auRa.stakeAmount(pools.at(i), address(this)) > 0) {
                stakePoolsCount++;
            }
        }

        pool = new address[](stakePoolsCount);
        uint256 j = 0;
        for (uint256 i = 0; i < pools.length(); ++i) {
            if (auRa.stakeAmount(pools.at(i), address(this)) > 0) {
                pool[j] = pools.at(i);
            }
        }
    }

    /// @notice 设置 staking 节点地址
    /// @param _stakingAuRa staking 节点地址
    function setStakingAuRa(address _stakingAuRa) public onlyAdmin {
        address oldStaking = stakingAuRa;
        stakingAuRa = _stakingAuRa;

        emit SetStakingAuRa(oldStaking, stakingAuRa);
    }

    /// @notice 设置 validatorSetContract 地址
    /// @param _validatorSetContract validatorSetContract 地址
    function setValidatorSetContract(address _validatorSetContract)
        public
        onlyAdmin
    {
        address oldValidatorSetContract = validatorSetContract;
        validatorSetContract = _validatorSetContract;

        emit SetValidatorSetContract(
            oldValidatorSetContract,
            validatorSetContract
        );
    }

    /// @notice 设置预备管理员
    /// @param _proposedAdmin 预备管理员地址
    function setProposedAdmin(address _proposedAdmin) public onlyAdmin {
        proposedAdmin = _proposedAdmin;

        emit SetProposedAdmin(proposedAdmin);
    }

    /// @notice 增加节点
    /// @param _pool 节点地址
    function addPool(address _pool) public onlyAdmin {
        pools.add(_pool);
    }

    /// @notice 移除节点
    /// @param _pool 节点地址
    function remove(address _pool) public onlyAdmin {
        pools.remove(_pool);
    }

    /// @notice claim 管理员
    function claimAdmin() public {
        require(msg.sender == proposedAdmin, "ProposedAdmin required");
        address oldAdmin = admin;
        admin = proposedAdmin;
        proposedAdmin = address(0);

        emit ClaimAdmin(oldAdmin, admin);
    }

    /// @notice 取奖励
    /// @param _stakingEpochs 锁仓 epoch（可传空）
    /// @param _poolStakingAddress 节点地址
    function claimReward(
        uint256[] memory _stakingEpochs,
        address _poolStakingAddress
    ) public {
        IStakingAuRa auRa = IStakingAuRa(stakingAuRa);
        auRa.claimReward(_stakingEpochs, _poolStakingAddress);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function approve(address guy, uint256 wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint256 wad) public returns (bool) {
        updateFor(msg.sender);
        updateFor(dst); 
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) public returns (bool) {
        require(balanceOf[src] >= wad);
        updateFor(src);
        updateFor(dst); 

        if (src != msg.sender && allowance[src][msg.sender] != uint256(-1)) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }

        balanceOf[src] -= wad;
        balanceOf[dst] += wad;

        emit Transfer(src, dst, wad);

        return true;
    }

    function getClaimableCurrent(address account) public returns(uint256) {
      updateFor(account);
      return claimable[account];
    }

    function calcInterest() public view returns(uint256) {
      uint256 currentBalance = address(this).balance;
      uint256 totalStaked = getAllStaked();
      if(totalStaked.add(currentBalance) <= _totalSupply){
        return 0;
      }else{
        return totalStaked.add(currentBalance).sub(_totalSupply);
      } 
    }

    function calcBalance() public view returns(uint256) {
      uint256 currentBalance = address(this).balance;
      uint256 interest = calcInterest();
      if(currentBalance <= interest){
        return 0;
      }else{
        return currentBalance.sub(interest);
      }
    }

    function claimInterest() public payable returns(uint256) {
        updateFor(msg.sender);
        msg.sender.transfer(claimable[msg.sender]);
        claimable[msg.sender] = 0;
        bal = calcInterest();
    }

    function updateFor(address recipient) public {
        _update();
        uint256 _supplied = balanceOf[recipient];
        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[recipient];
            supplyIndex[recipient] = index;
            uint256 _delta = index.sub(_supplyIndex, "index delta");
            if (_delta > 0) {
                uint256 _share = _supplied.mul(_delta).div(1e18);
                claimable[recipient] = claimable[recipient].add(_share);
            }
        } else {
            supplyIndex[recipient] = index;
        }
    }

    function update() external {
        _update();
    }

    function _update() internal {
        if (_totalSupply > 0) {
            uint256 _bal = calcInterest();
            if (_bal > bal) {
                uint256 _diff = _bal.sub(bal, "bal _diff");
                if (_diff > 0) {
                    uint256 _ratio = _diff.mul(1e18).div(_totalSupply);
                    if (_ratio > 0) {
                        index = index.add(_ratio);
                        bal = _bal;
                    }
                }
            }
        }
    }

    function _mint(address dst, uint256 amount) internal {
        updateFor(dst);
        // mint the amount
        _totalSupply = _totalSupply.add(amount);
        // transfer the amount to the recipient
        balanceOf[dst] = balanceOf[dst].add(amount);
        emit Transfer(address(0), dst, amount);
    }

    function _burn(address dst, uint256 amount) internal {
        updateFor(dst);
        // mint the amount
        _totalSupply = _totalSupply.sub(amount);
        // transfer the amount to the recipient
        balanceOf[dst] = balanceOf[dst].sub(amount);
        emit Transfer(dst, address(0), amount);
    }

    fallback() external {}

    receive() external payable {}
}
