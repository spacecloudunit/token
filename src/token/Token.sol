pragma solidity ^0.4.24;

// ----------------------------------------------------------------------------
// 'SCU' 'Space.Cloud.Unit Token' token contract
//
// Symbol      : SCU
// Name        : Space.Cloud.Unit
// Total supply: 150,000,000.000000000000000000
// Decimals    : 18
//
// (c) openzepplin / Smart Contract Solutions, Inc 2016. The MIT Licence.
// (c) Max / SCU GmbH 2018. The MIT Licence.
// ----------------------------------------------------------------------------

import "../openzepplin/contracts/math/SafeMath.sol";
import "../openzepplin/contracts/ownership/Ownable.sol";
import "../openzepplin/contracts/token/ERC20/DetailedERC20.sol";
import "../openzepplin/contracts/token/ERC20/PausableToken.sol";
import "../openzepplin/contracts/token/ERC20/CappedToken.sol";
import "../openzepplin/contracts/token/ERC20/BurnableToken.sol";

contract SCU is DetailedERC20, Ownable, PausableToken, CappedToken, BurnableToken {
    constructor() public {
        symbol = "SCU";
        name = "Space.Cloud.Unit";
        decimals = 18;
        _totalSupply = 150000000 * 10**uint(decimals);
        balances[owner] = _totalSupply;
        // Set: CappedToken.cap
        cap = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }
}
