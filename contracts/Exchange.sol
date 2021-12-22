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
    event Approval(address owner, address spender, uint256 value);

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

    function removeLiquidity(uint256 amount, uint256 minETH, uint256 minTokens, uint deadline) public returns (uint256, uint256) {
        require(amount > 0);
        require(block.timestamp < deadline);
        require(minETH > 0);
        require(minTokens > 0);
        uint256 totalLiquidity = totalSupply;
        require(totalLiquidity > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethAmount = amount * address(this).balance / totalLiquidity;
        uint256 tokenAmount = amount * tokenReserve / totalLiquidity;
        require(ethAmount >= minETH);
        require(tokenAmount >= minTokens);
        balances[msg.sender] = balances[msg.sender] - amount;
        payable(msg.sender).transfer(ethAmount);
        require(token.transfer(msg.sender, tokenAmount));
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
        emit Transfer(msg.sender, address(0), amount);
        return (ethAmount, tokenAmount);
    }

    function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        require(inputReserve > 0); 
        require(outputReserve > 0);
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        return numerator / denominator;
    }

    function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns (uint256) {
        require(inputReserve > 0);
        require(outputReserve > 0);
        uint256 numerator = inputReserve * outputReserve * 1000;
        uint256 denominator = (outputReserve - outputAmount) * 997;
        return numerator / denominator + 1;
    }

    function ethToTokenInput(uint256 ethSold, uint256 minTokens, uint deadline, address buyer, address recipient) private returns (uint256) {
        require(deadline >= block.timestamp); 
        require(ethSold > 0);
        require(minTokens > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokensBought = getInputPrice(ethSold, address(this).balance - ethSold, tokenReserve);
        require(tokensBought > minTokens);
        require(token.transfer(recipient, tokensBought));
        emit TokenPurchase(buyer, ethSold, tokensBought);
        return tokensBought;
    }

    fallback () external payable {
        ethToTokenInput(msg.value, 1, block.timestamp, msg.sender, msg.sender);
    }

    function ethToTokenSwapInput(uint256 minTokens, uint deadline) public payable returns (uint256) {
        return ethToTokenInput(msg.value, minTokens, deadline, msg.sender, msg.sender);
    }

    function ethToTokenTranfserInput(uint256 minTokens, uint deadline, address recipient) public payable returns (uint256) {
        require(recipient != address(this));
        require(recipient != address(0));
        return ethToTokenInput(msg.value, minTokens, deadline, msg.sender, recipient);
    }

    function ethToTokenOutput(uint256 tokensBought, uint256 maxETH, uint deadline, address buyer, address recipient) private returns (uint256) {
        require(deadline >= block.timestamp);
        require(tokensBought > 0);
        require(maxETH > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethSold = getOutputPrice(tokensBought, address(this).balance - maxETH, tokenReserve);
        uint256 ethRefund = maxETH - ethSold;
        if (ethRefund > 0) {
            payable(buyer).transfer(ethRefund);
        }
        require(token.transfer(recipient, tokensBought));
        emit TokenPurchase(buyer, ethSold, tokensBought);
        return ethSold;
    }

    function ethToTokenSwapOutput(uint256 tokensBought, uint deadline) public payable returns (uint256) {
        return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, msg.sender);
    }

    function ethToTokenTransferOuptut(uint256 tokensBought, uint deadline, address recipient) public payable returns (uint256) {
        require(recipient != address(this));
        require(recipient != address(0));
        return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, recipient);
    }

    function tokenToEthInput(uint256 tokensSold, uint256 minETH, uint deadline, address buyer, address recipient) private returns (uint256) {
        require(deadline >= block.timestamp);
        require(tokensSold > 0);
        require(minETH > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        uint256 weiBought = ethBought * 10^18;
        require(payable(recipient).send(weiBought));
        require(token.transferFrom(buyer, address(this), tokensSold));
        emit EthPurchase(buyer, tokensSold, weiBought);
        return weiBought;
    }


    function tokenToEthSwapInput(uint256 tokensSold, uint256 minETH, uint deadline) public returns (uint256) {
        return tokenToEthInput(tokensSold, minETH, deadline, msg.sender, msg.sender);
    }

    function tokenToEthTrasnferInput(uint256 tokensSold, uint256 minETH, uint deadline, address recipient) public returns (uint256) {
        return tokenToEthInput(tokensSold, minETH, deadline, msg.sender, recipient);
    }

    function tokenToEthOutput(uint256 ethBought, uint256 maxTokens, uint deadline, address buyer, address recipient) private returns (uint256) {
        require(deadline >= block.timestamp);
        require(ethBought > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(ethBought, tokenReserve, address(this).balance);
        require(maxTokens >= tokensSold);
        require(payable(recipient).send(ethBought));
        require(token.transferFrom(buyer, address(this), tokensSold));
        emit EthPurchase(buyer, tokensSold, ethBought);
        return tokensSold;
    } 

    function tokenToEthSwapOutput(uint256 ethBought, uint256 maxTokens, uint deadline) public returns (uint256) {
        return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, msg.sender);
    }

    function tokenToEthTransferOutput(uint256 ethBought, uint256 maxTokens, uint deadline, address recipient) public returns (uint256) {
        return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, recipient);
    }


// @private
// def tokenToTokenInput(tokens_sold: uint256, min_tokens_bought: uint256, min_eth_bought: uint256(wei), deadline: timestamp, buyer: address, recipient: address, exchange_addr: address) -> uint256:
    function tokenToTokenInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint deadline, address buyer, address recipient, address exchangeAddr) private returns (uint256) {
        require(deadline > block.timestamp);
        require(tokensSold > 0);
        require(minTokensBought > 0);
        require(minEthBought > 0);
        require(exchangeAddr != address(this));
        require(exchangeAddr != address(0));
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        uint256 weiBought = ethBought * 10^18;
        require(weiBought >= minEthBought);
        require(token.transferFrom(buyer, address(this), tokensSold));
        uint256 tokensBought = Exchange(exchangeAddr).ethToTokenTransferInput(minTokensBought, deadline, buyer, recipient, weiBought);
        emit EthPurchase(buyer, tokensSold, weiBought);
        return tokensBought;
    } 

    function tokenToTokenSwapInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint deadline, address tokenAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokenAddr);
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, msg.sender, exchangeAddr);
    }
    
    function tokenToTokenTranferInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint deadline, address buyer, address recipient, address tokenAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokenAddr);
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, buyer, recipient, exchangeAddr);
    }

    function tokenToTokenOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint deadline, address buyer, address recipient, address exchangeAddr) private returns (uint256) {
        require(deadline >= block.timestamp);
        require(tokensBought > 0 && maxEthSold > 0);
        require(exchangeAddr != address(this) && exchangeAddr != address(0));
        uint256 ethBought = Exchange(exchangeAddr).getEthToTokenOutputPrice(tokensBought);
        uint256 tokenReserve = token.balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(ethBought, tokenReserve, address(this).balance);
        require(maxTokensSold >= tokensSold && maxEthSold >= ethBought);
        require(token.transferFrom(buyer, address(this), tokensSold));
        uint256 ethSold = Exchange(exchangeAddr).ethToTokenTransferOuptut(tokensBought, deadline, recipient);
        emit EthPurchase(buyer, tokensSold, ethBought);
        return tokensSold;
    }

    function tokenToTokenSwapOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint deadline, address tokenAddr) public returns (uint256) {
        address exchangeAddr = Exchange.getExchange(tokenAddr);
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    function tokenToTokenTransferOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint deadline, address recipient, address tokenAddr) public returns (uint256) {
        address exchangeAddr = factory.getExchange(tokenAddr);
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, recipient, exchangeAddr);
    }

    function tokenToExchangeSwapInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint deadline, address exchangeAddr) public returns (uint256) {
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    function tokenToExchangeTransferInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint deadline, address recipient, address exchangeAddr) public returns (uint256) {
        require(recipient != address(this));
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, recipient, exchangeAddr);
    }

    function tokenToExchangeSwapOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint deadline, address exchangeAddr) public returns (uint256) {
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    function tokenToExchangeTransferOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint deadline, address recipient, address exchangeAddr) public returns (uint256) {
        require(recipient != address(this));
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.semder, recipient, exchangeAddr);
    }   

    function getEthToTokenOutputPrice(uint256 tokensBought) public view returns (uint256) {
        require(tokensBought > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        return getOutputPrice(tokensBought, address(this).balance, tokenReserve);
    }

    function getTokenToEthInputPrice(uint256 tokensSold) public view returns (uint256) {
        require(tokensSold > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        return getInputPrice(tokensSold, tokenReserve, address(this).balance);
    }

    function getTOkenToEthOutputPrice(uint256 ethBought) public view returns (uint256) {
        require(ethBought > 0);
        uint256 tokenReserve = token.balanceOf(address(this));
        return getOutputPrice(ethBought, tokenReserve, address(this).balance);
    }

    function tokenAddress() public view returns (address) {
        return address(token);
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender] - _value;
        balances[_to] = balances[_to] + _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        balances[_from] = balances[_from] - _value;
        balances[_to] = balances[_to] + _value;
        allowances[_from][msg.sender] = allowances[_from][msg.sender] - _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowances[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        return allowances[_owner][_spender];
    }

}
