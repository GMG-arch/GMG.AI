// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

contract MintToken is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public usdt;
    IERC20 public targetToken;
    IUniswapV2Router02 public router;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    event Mint(
        address indexed user,
        uint256 usdtAmount,
        uint256 burnedAmount,
        uint256 timestamp
    );

    constructor(
        address _usdt,
        address _targetToken,
        address _router
    ) {
        require(
            _usdt != address(0) &&
                _targetToken != address(0) &&
                _router != address(0),
            "invalid address"
        );

        usdt = IERC20(_usdt);
        targetToken = IERC20(_targetToken);
        router = IUniswapV2Router02(_router);
    }

    function mint(uint256 amount) external {
        require(amount >= 100 * 1e18, "Minimum mintage 100");

        // Pull USDT from user
        usdt.safeTransferFrom(msg.sender, address(this), amount);

        // Approve router
        usdt.safeApprove(address(router), 0);
        usdt.safeApprove(address(router), amount);

        // Swap path: USDT -> targetToken
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(targetToken);

        uint256[] memory expected = router.getAmountsOut(amount, path);
        uint256 minOut = (expected[1] * 95) / 100;

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amount,
            minOut,
            path,
            address(this),
            block.timestamp + 600
        );

        uint256 received = amounts[1];

        // Burn to dead address
        targetToken.safeTransfer(DEAD, received);

        emit Mint(msg.sender, amount, received, block.timestamp);
    }

    function rescueToken(
        address _token,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(to != address(0), "zero address");

        IERC20 t = IERC20(_token);
        uint256 bal = t.balanceOf(address(this));
        uint256 out = amount == 0 ? bal : amount;

        require(bal >= out, "insufficient");

        t.safeTransfer(to, out);
    }
}
