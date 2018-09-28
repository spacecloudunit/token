pragma solidity ^0.4.23;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./Ownable.sol";

contract SCUToken is ERC20, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint64;

    // ERC20 standard variables
    string public name = "SCU Token";
    string public symbol = "SCU";
    uint8 public decimals = 18;
    uint256 public initialSupply = 28100000 * (10 ** uint256(decimals));
    uint256 public totalSupply;

    // Address of the ICO contract
    address public crowdSaleContract;

    uint64 public assetValue;

    // Fee to charge on every transfer (e.g. 15 is 1,5%)
    uint64 public feeCharge;

    // Global freeze of all transfers
    bool public freezeTransfer;

    // Maximum value for feeCharge
    uint64 private constant feeChargeMax = 20;

    // Address of the account/wallet which should receive the fees
    address private feeReceiver;

    // Mappings of addresses for balances, allowances and frozen accounts
    mapping(address => uint256) internal balances;
    mapping(address => mapping (address => uint256)) internal allowed;
    mapping(address => bool) public frozenAccount;

    // Event definitions
    event Fee(address indexed payer, uint256 fee);
    event FeeCharge(uint64 oldValue, uint64 newValue);
    event AssetValue(uint64 oldValue, uint64 newValue);
    event Burn(address indexed burner, uint256 value);
    event FrozenFunds(address indexed target, bool frozen);
    event FreezeTransfer(bool frozen);

    // Constructor which gets called once on contract deployment
    constructor(address _tokenOwner) public {
        owner = _tokenOwner;
        crowdSaleContract = msg.sender;
        feeReceiver = msg.sender;
        totalSupply = initialSupply;
        balances[msg.sender] = initialSupply;
        assetValue = 0;
        feeCharge = 15;
        freezeTransfer = false;
    }

    /**
     * @notice Returns the total supply of tokens.
     * @dev The total supply is the amount of tokens which are currently in circulation.
     * @return Amount of tokens in Sip.
     */
    function totalSupply() public view returns (uint256) {
        return totalSupply;
    }

    /**
     * @notice Gets the balance of the specified address.
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount of tokens owned by the passed address.
     */
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    /**
     * @dev Internal transfer, can only be called by this contract.
     * Will throw an exception to rollback the transaction if anything is wrong.
     * @param _from The address from which the tokens should be transfered from.
     * @param _to The address to which the tokens should be transfered to.
     * @param _value The amount of tokens which should be transfered in Sip.
     */
    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0));
        require(_value >= 1000);
        require(!freezeTransfer);
        require(!frozenAccount[_from]);
        require(!frozenAccount[_to]);

        uint256 transferValue = _value;
        if (msg.sender != owner && msg.sender != crowdSaleContract) {
            uint256 fee = _value.div(1000).mul(feeCharge);
            transferValue = _value.sub(fee);
            balances[feeReceiver] = balances[feeReceiver].add(fee);
            emit Fee(msg.sender, fee);
        }

        // SafeMath.sub will throw if there is not enough balance.
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(transferValue);
        emit Transfer(_from, _to, transferValue);
    }

    /**
     * @notice Transfer tokens to a specified address. The message sender has to pay the fee.
     * @dev Calls _transfer with message sender address as _from parameter.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred in Sip.
     * @return Indicates if the transfer was successful.
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * @notice Transfer tokens from one address to another. The message sender has to pay the fee.
     * @dev Calls _transfer with the addresses provided by the transactor.
     * @param _from The address which you want to send tokens from.
     * @param _to The address which you want to transfer to.
     * @param _value The amount of tokens to be transferred in Sip.
     * @return Indicates if the transfer was successful.
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_value <= allowed[_from][msg.sender]);

        _transfer(_from, _to, _value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        return true;
    }

    /**
     * @notice Approve the passed address to spend the specified amount of tokens on behalf of the transactor.
     * @dev Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which is allowed to retrieve the tokens.
     * @param _value The amount of tokens to be spent in Sip.
     * @return Indicates if the approval was successful.
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        require(_spender != address(0));
        require(_value >= 1000);

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @notice Returns the amount of tokens that the owner allowed to the spender.
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner The address which owns the tokens.
     * @param _spender The address which is allowed to retrieve the tokens.
     * @return The amount of tokens still available for the spender in Sip.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
     * @notice Increase the amount of tokens that an owner allowed to a spender.
     * @dev Approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which is allowed to retrieve the tokens.
     * @param _addedValue The amount of tokens to increase the allowance by in Sip.
     * @return Indicates if the approval was successful.
     */
    function increaseApproval(address _spender, uint256 _addedValue) public returns (bool) {
        require(_spender != address(0));
        require(_addedValue >= 1000);
        
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @notice Decrease the amount of tokens that an owner allowed to a spender. 
     * @dev Approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which is allowed to retrieve the tokens.
     * @param _subtractedValue The amount of tokens to decrease the allowance by in Sip.
     * @return Indicates if the approval was successful.
     */
    function decreaseApproval(address _spender, uint256 _subtractedValue) public returns (bool) {
        require(_spender != address(0));
        require(_subtractedValue >= 1000);

        uint256 oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    } 

    /**
     * @notice Burns a specific amount of tokens.
     * @dev Tokens get technically destroyed by this function and are therefore no longer in circulation afterwards.
     * @param _value The amount of token to be burned in Sip.
     */
    function burn(uint256 _value) public {
        require(_value <= balances[msg.sender]);
        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Burn(burner, _value);
        emit Transfer(burner, address(0), _value);
    }

    /**
     * @notice Not for public use!
     * @param _value The new value of the asset in EUR cents.
     */
    function setAssetValue(uint64 _value) public onlyOwner {
        uint64 oldValue = assetValue;
        assetValue = _value;
        emit AssetValue(oldValue, _value);
    }

    /**
     * @notice Not for public use!
     * @dev Modifies the feeCharge which calculates the fee for each transaction.
     * @param _value The new value of the feeCharge as fraction of 1000 (e.g. 15 is 1,5%).
     */
    function setFeeCharge(uint64 _value) public onlyOwner {
        require(_value <= feeChargeMax);
        uint64 oldValue = feeCharge;
        feeCharge = _value;
        emit FeeCharge(oldValue, _value);
    }


    /**
     * @notice Not for public use!
     * @dev Prevents/Allows target from sending & receiving tokens.
     * @param _target Address to be frozen.
     * @param _freeze Either to freeze or unfreeze it.
     */
    function freezeAccount(address _target, bool _freeze) public onlyOwner {
        require(_target != address(0));

        frozenAccount[_target] = _freeze;
        emit FrozenFunds(_target, _freeze);
    }

    /**
     * @notice Not for public use!
     * @dev Globally freeze all transfers for the token.
     * @param _freeze Freeze or unfreeze every transfer.
     */
    function setFreezeTransfer(bool _freeze) public onlyOwner {
        freezeTransfer = _freeze;
        emit FreezeTransfer(_freeze);
    }

    /**
     * @notice Not for public use!
     * @dev Allows the owner to set the address which receives the fees.
     * @param _feeReceiver theTaddress which should receive fees.
     */
    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        require(_feeReceiver != address(0));
        feeReceiver = _feeReceiver;
    }
}
