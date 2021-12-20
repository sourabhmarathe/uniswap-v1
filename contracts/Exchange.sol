//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange {
    bytes32 public name;
    bytes32 public symbol;
    uint256 public decimals;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    IERC20 token;
    address factory;

    constructor(address tokenAddr) {
        require(factory != address(0));
        require(token != IERC20(address(0)));
        require(tokenAddr != address(0));
        factory = msg.sender;
        token = IERC20(tokenAddr);
        name = 0x556e697377617020563100000000000000000000000000000000000000000000;
        symbol = 0x554e492d56310000000000000000000000000000000000000000000000000000;
        decimals = 18;
    }

    event TokenPurchase(address buyer, uint256 ethSold, uint256 tokensBought);
    event EthPurchase(address buyer, uint256 tokensSold, uint256 ethBought);
    event AddLiquidity(address provider, uint256 ethAmount, uint256 tokenAmount);
    event RemoveLiquidity(address provider, uint256 ethAmount, uint256 tokenAmount);
    event Transfer(address from, address to, uint256 value);
    event Approval(address owner, address spender, address value);

    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint deadline) payable public returns (uint256) {
        require(deadline > block.timestamp);
        require(maxTokens > 0);
        require(msg.value > 0);
        
        uint256 totalLiquidity = totalSupply;
        if (totalLiquidity > 0) {
            require(minLiquidity > 0);
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = token.balanceOf(address(this));
            uint256 tokenAmount = msg.value * tokenReserve / (ethReserve + 1);
            uint256 liquidityMinted = msg.value * totalLiquidity / ethReserve;
            require(maxTokens >= tokenAmount && liquidityMinted >= minLiquidity);
            balances[msg.sender] += liquidityMinted;
            totalSupply = totalLiquidity + liquidityMinted;
            token.transferFrom(msg.sender, address(this), tokenAmount);
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, liquidityMinted);
            return liquidityMinted;
        } else {
            require(factory != address(0));
            require(token != IERC20(address(0)));
            require(msg.value >= 1000000000);
            uint256 tokenAmount = maxTokens;
            uint256 initialLiquidity = address(this).balance; 
            totalSupply = initialLiquidity;
            balances[msg.sender] = initialLiquidity;
            require(token.transferFrom(msg.sender, address(this), tokenAmount));
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            emit Transfer(address(0), msg.sender, initialLiquidity);
            return initialLiquidity;
        }
    }
}
