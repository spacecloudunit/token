pragma solidity ^0.4.23;

import "./Fiat.sol";

contract FiatContractMock is FiatContract {

    uint256 private price;
    uint256 private createdAt;

    constructor() public {
        // price = 1 szabo;
        //price = 21150592216582; // 475€ as 0.01€ in WEI
        price = 10000000000; // 1 ETH = 1.000.000 EUR
        createdAt = now;
    }

    function setPrice(uint256 _price) public {
        require(_price > 0);
        price = _price;
    }

    function ETH(uint _id) public view returns (uint256) {
        require(_id == 0); // to support only ETH
        return 1 ether;
    }

    function EUR(uint _id) public view returns (uint256) {
        require(_id == 0); // to support only ETH
        return price; 
    }

    function USD(uint _id) public view returns (uint256) {
        require(_id == 0); // to support only ETH
        return price; 
    }

    function GBP(uint _id) public view returns (uint256) {
        require(_id == 0); // to support only ETH
        return price; 
    }

    function updatedAt(uint _id) public view returns (uint) {
        require(_id == 0); // to support only ETH
        return createdAt;
    }

}
