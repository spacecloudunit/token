pragma solidity ^0.4.21;

/*

  BASIC ERC20 Sale Contract


  @author Hunter Long
  @repo https://github.com/hunterlong/ethereum-ico-contract
  (c) Max / SCU GmbH 2018. The MIT Licence.
*/


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;

    /** WhiteList users and their phase status */
    mapping(address => uint8) public whitelist;

    /** operator address */
    address public opsAddress;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event WhitelistUpdated(address indexed _account, uint8 _phase);


    /** Modifier to check If the sender is the owner of the contract */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
        owner = msg.sender;
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}


contract ERC20 {
    uint public totalSupply;
    function balanceOf(address who) public constant returns (uint);
    function allowance(address owner, address spender) public constant returns (uint);
    function transfer(address to, uint value) public returns (bool ok);
    function transferFrom(address from, address to, uint value) public returns (bool ok);
    function approve(address spender, uint value) public returns (bool ok);
    function mint(address to, uint256 value) public returns (uint256);
}


contract SimpleSaleTest is Ownable {

    uint256 public totalSold;
    uint public exchangeRate;
    ERC20 public Token;
    address public ETHWallet;

    event Contribution(address from, uint256 amount);
    event ReleaseTokens(address from, uint256 amount);

    constructor(address eth_wallet, address token_address) public {
        ETHWallet = eth_wallet;
        Token = ERC20(token_address);
        exchangeRate = 2000;
    }

    function () public payable {
        require(msg.value>0);
        uint256 amount = msg.value * exchangeRate;
        totalSold += amount;
        ETHWallet.transfer(msg.value);
        Token.transferFrom(owner, msg.sender, amount);
        emit Contribution(msg.sender, amount);
    }

    // CONTRIBUTE FUNCTION
    // converts ETH to TOKEN and sends new TOKEN to the sender
    function contribute() external payable {
        require(msg.value>0);
        require(whitelist[msg.sender] == 1);
        uint256 amount = msg.value * exchangeRate;
        totalSold += amount;
        ETHWallet.transfer(msg.value);
        Token.transferFrom(owner, msg.sender, amount);
        emit Contribution(msg.sender, amount);
    }

    // update the ETH/COIN rate
    function updateRate(uint256 rate) external onlyOwner {
        exchangeRate = rate;
    }

    /** Internal Functions */

    /**
     *  @notice checks If the sender is the owner of the contract.
     *
     *  @param _address address to be checked if valid owner or not.
     *
     *  @return bool valid owner or not.
     */
    function isOwner(
        address _address)
        internal
        view
        returns (bool)
    {
        return (_address == owner);
    }

    /**
     *  @notice check If the sender is the ops address.
     *
     *  @param _address address to be checked for ops.
     *
     *  @return bool valid ops or not.
     */
    function isOps(
        address _address)
        internal
        view
        returns (bool)
    {
        return (opsAddress != address(0) && _address == opsAddress);
    }

    /** External Functions */

    /**
     *  @notice Owner can change the verified operator address.
     *
     *  @param _opsAddress address to be set as ops.
     *
     *  @return bool address is successfully set as ops or not.
     */
    function setOpsAddress(
        address _opsAddress)
        external
        onlyOwner
        returns (bool)
    {
        require(_opsAddress != owner);
        require(_opsAddress != address(this));
        require(_opsAddress != address(0));

        opsAddress = _opsAddress;

        return true;
    }

    /**
     *  @notice function to whitelist an address which can be called only by the ops address.
     *
     *  @param _account account address to be whitelisted
     *  @param _phase 0: unwhitelisted, 1: whitelisted
     *
     *  @return bool address is successfully whitelisted/unwhitelisted.
     */
    function updateWhitelist(
        address _account,
        uint8 _phase)
        returns (bool)
    {
        require(_account != address(0));
        require(_phase <= 1);
        require(isOps(msg.sender));

        whitelist[_account] = _phase;

        emit WhitelistUpdated(_account, _phase);

        return true;
    }



}
