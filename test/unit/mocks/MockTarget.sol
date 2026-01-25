// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Simplified Mock for testing DAO proposals
/// @dev Simulates DeFi protocols WITHOUT complex parameters
contract MockTarget {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    uint256 public callCount;
    address public lastCaller;
    uint256 public totalEthReceived;
    bytes public lastCallData;
    
    uint256 public value;
    mapping(address => uint256) public balances;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event FunctionCalled(address indexed caller, string functionName, uint256 ethValue);
    event EthReceived(address indexed sender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                        SIMPLE DeFi FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Deposit funds (like Aave)
    function deposit(uint256 amount) external payable {
        callCount++;
        lastCaller = msg.sender;
        totalEthReceived += msg.value;
        
        balances[msg.sender] += amount;
        
        emit FunctionCalled(msg.sender, "deposit", msg.value);
    }
    
    /// @notice Withdraw funds (like Aave)
    function withdraw(uint256 amount) external {
        callCount++;
        lastCaller = msg.sender;
        
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit FunctionCalled(msg.sender, "withdraw", 0);
    }
    
    /// @notice Swap tokens (like Uniswap) 
    function swap(uint256 amountIn) external payable returns (uint256 amountOut) {
        callCount++;
        lastCaller = msg.sender;
        totalEthReceived += msg.value;
        
        // Simple 1:1 swap simulation
        amountOut = amountIn;
        balances[msg.sender] += amountOut;
        
        emit FunctionCalled(msg.sender, "swap", msg.value);
        return amountOut;
    }
    
    /// @notice Stake ETH (like Lido) 
    function stake() external payable returns (uint256) {
        callCount++;
        lastCaller = msg.sender;
        totalEthReceived += msg.value;
        
        balances[msg.sender] += msg.value;
        
        emit FunctionCalled(msg.sender, "stake", msg.value);
        return msg.value;
    }
    
    /// @notice Pay someone (generic payment)
    function pay(address recipient, uint256 amount) external payable {
        callCount++;
        lastCaller = msg.sender;
        totalEthReceived += msg.value;
        
        require(msg.value >= amount, "Insufficient ETH");
        payable(recipient).transfer(amount);
        
        emit FunctionCalled(msg.sender, "pay", msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                        UTILITY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Set a value 
    function setValue(uint256 _value) external {
        callCount++;
        lastCaller = msg.sender;
        value = _value;
        emit FunctionCalled(msg.sender, "setValue", 0);
    }
    
    /// @notice Just receive ETH
    function receiveEth() external payable {
        callCount++;
        lastCaller = msg.sender;
        totalEthReceived += msg.value;
        emit EthReceived(msg.sender, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }
    
    function getCallInfo() external view returns (
        uint256 count,
        address caller,
        uint256 ethReceived
    ) {
        return (callCount, lastCaller, totalEthReceived);
    }

    /*//////////////////////////////////////////////////////////////
                            FALLBACK
    //////////////////////////////////////////////////////////////*/
    
    receive() external payable {
        totalEthReceived += msg.value;
        emit EthReceived(msg.sender, msg.value);
    }
}


/*//////////////////////////////////////////////////////////////
                    MOCK FAILING TARGET
//////////////////////////////////////////////////////////////*/

/// @notice Mock that always fails
contract MockFailingTarget {
    error AlwaysFails();
    
    function deposit(uint256) external payable {
        revert AlwaysFails();
    }
    
    function swap(uint256) external payable {
        revert AlwaysFails();
    }
    
    function alwaysFails() external pure {
        revert AlwaysFails();
    }
    
    receive() external payable {
        revert AlwaysFails();
    }

    
}