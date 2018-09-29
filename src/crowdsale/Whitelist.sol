pragma solidity ^0.4.21;

import "./Fiat.sol";
import "./FiatMock.sol";
import "./Ownable.sol";
//import "./Whitelist.sol";

/*
  BASIC ERC20 Sale Contract
  @author Hunter Long
  @repo https://github.com/hunterlong/ethereum-ico-contract
  (c) Max / SCU GmbH 2018. The MIT Licence.
*/

contract SimpleSaleTest is Ownable {

    FiatContract public fiat;
    ERC20 public Token;
    address public ETHWallet;
    Whitelist public white;

    uint256 public tokenSold;
    uint256 public tokenPrice;

    uint256 public deadline;
    uint256 public start;

    bool public crowdsaleClosed;

    event Contribution(address from, uint256 amount);
    event TokenSold(address indexed customer, uint256 amount);

    constructor(address eth_wallet, address token_address, address whitelistcontract) public {
        ETHWallet = eth_wallet;
        Token = ERC20(token_address);
        crowdsaleClosed = false;
        white = Whitelist(whitelistcontract);
        //need adjusted
        tokenSold = 0; //per contract
        tokenPrice = 20; //eurocents
        fiat = FiatContract(0x2CDe56E5c8235D6360CCbb0c57Ce248Ca9C80909);  // Rinkeby and in-memory
        //https://ethereum.stackexchange.com/questions/34110/compare-dates-in-solidity
        deadline = now + 110 * 1 days;
        start = now; //+ 110 * 1 days;

    }

    function () public payable {
        require(msg.value>0);
        require(white.isWhitelisted(msg.sender) == true);
        require(!crowdsaleClosed);
        require(now <= deadline && now >= start);
          //https://ethereum.stackexchange.com/questions/9256/float-not-allowed-in-solidity-vs-decimal-places-asked-for-token-contract
          //fee falls away

          uint256 amount = (msg.value / getTokenPrice()) * 1 ether;

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

          tokenSold = tokenSold + amount;
          emit TokenSold(msg.sender, amount);

          ETHWallet.transfer(msg.value);
          Token.transferFrom(owner, msg.sender, amount);
          emit Contribution(msg.sender, amount);
    }


    function getTokenPrice() internal view returns (uint256) {
        return getEtherInEuroCents() * tokenPrice / 100;
    }

    function getEtherInEuroCents() internal view returns (uint256) {
        return fiat.EUR(0) * 100;

    }

    function closeCrowdsale() public onlyOwner returns (bool) {
        crowdsaleClosed = true;
        return true;
    }



}

contract Whitelist {
    function isWhitelisted(address _account) constant returns (bool);

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
