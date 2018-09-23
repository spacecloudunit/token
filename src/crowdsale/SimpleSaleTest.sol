pragma solidity ^0.4.21;

import "./Fiat.sol";
import "./FiatMock.sol";
import "./Ownable.sol";
/*
  BASIC ERC20 Sale Contract
  @author Hunter Long
  @repo https://github.com/hunterlong/ethereum-ico-contract
  (c) Max / SCU GmbH 2018. The MIT Licence.
*/

contract SimpleSaleTest is Ownable {

    mapping(address => uint8) public whitelist;

    address public opsAddress;
    uint256 public totalSold; //eurocents

    FiatContract public fiat;
    ERC20 public Token;
    address public ETHWallet;

    uint256 public tokenSold;
    uint256 public tokenPrice;

    uint256 public deadline;
    uint256 public start;

    bool public crowdsaleClosed;


    event WhitelistUpdated(address indexed _account, uint8 _phase);
    event Contribution(address from, uint256 amount);

    constructor(address eth_wallet, address token_address) public {
        ETHWallet = eth_wallet;
        Token = ERC20(token_address);
        crowdsaleClosed = false;

        //need adjusted
        tokenSold = 0; //per contract
        tokenPrice = 20; //eurocents
        fiat = new FiatContractMock();  // Rinkeby and in-memory
        //https://ethereum.stackexchange.com/questions/34110/compare-dates-in-solidity
        deadline = now + 110 * 1 days;
        start = now; //+ 110 * 1 days;

    }

    function () public payable {
        require(msg.value>0);
        //require(whitelist[msg.sender] == 1);
        require(!crowdsaleClosed);
        require(now <= deadline && now >= start);
          //https://ethereum.stackexchange.com/questions/9256/float-not-allowed-in-solidity-vs-decimal-places-asked-for-token-contract
          //fee falls away

          uint256 amount = (((msg.value * 100) * getTokenPrice()) / 100);
          totalSold += (amount / tokenPrice) * 100;

          //afterwards calculate  pre sale bonusprogramm
          if(tokenSold < 6000000)
          {
              amount = amount + ((amount * 25) / 100);
          }
          else if(tokenSold < 12000000)
          {
              amount = amount + ((amount * 15) / 100);
          }
          else
          {
              amount = amount + ((amount * 10) / 100);
          }

          ETHWallet.transfer(msg.value);
          Token.transferFrom(owner, msg.sender, amount);
          emit Contribution(msg.sender, amount);
    }


    function getTokenPrice() internal view returns (uint256) {
        return getEtherInEuroCents() * tokenPrice / 100;
    }

    function getEtherInEuroCents() internal view returns (uint256) {
        //return fiat.EUR(0) * 100;
        // Mocked 1 eth 200 EUR
        return 200 * 100;
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
    function closeCrowdsale() public onlyOwner returns (bool) {
        crowdsaleClosed = true;
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



contract ERC20 {
    uint public totalSupply;
    function balanceOf(address who) public constant returns (uint);
    function allowance(address owner, address spender) public constant returns (uint);
    function transfer(address to, uint value) public returns (bool ok);
    function transferFrom(address from, address to, uint value) public returns (bool ok);
    function approve(address spender, uint value) public returns (bool ok);
    function mint(address to, uint256 value) public returns (uint256);
}
