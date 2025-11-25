# SHIB 风格 Meme 代币（Foundry + Solidity）

## 概述
- 合约：`src/MemeToken.sol`（含交易税、自动回流、交易限制、UniswapV2 集成）
- 部署脚本：`script/Deploy.s.sol`
- 添加流动性脚本：`script/AddLiquidity.s.sol`
- 基础测试：`test/MemeToken.t.sol`

## 安装依赖
- 在项目根目录执行：
```
forge install OpenZeppelin/openzeppelin-contracts foundry-rs/forge-std --no-git
```

## 构建与测试
```
forge build
forge test -vv
```

## 部署步骤
1. 配置环境变量：
   - `PRIVATE_KEY`：部署账户私钥（勿泄露）
   - `TAX_WALLET`：税费接收地址
   - 可选 `ROUTER`：UniswapV2 Router 地址（默认主网 `0x7a250d...`）
2. 执行部署脚本：
```
forge script script/Deploy.s.sol --rpc-url <YOUR_RPC> --broadcast --verify
```
- 部署后合约已自动创建交易对，并调用 `enableTrading()` 开放交易。

## 代币交易
- 税费：默认 `taxBps = 300`（3%），可由拥有者调整 `setTax(uint16)`。
- 税费流向：税费先进入合约余额；开启自动回流时触发 `swap+addLiquidity`，否则可通过 `withdrawTaxTokens`/`withdrawETH` 提取至 `taxWallet`。
- 免税地址：`setFeeExempt(address,bool)` 设置。

## 交易限制
- 单笔最大额度：`setMaxTxAmount(uint256)`，默认 2% 总供给。
- 每日交易次数：`setMaxDailyTxCount(uint32)`，默认 50 次。
- 限制豁免：`setLimitExempt(address,bool)`（如路由器/LP/合约/拥有者默认豁免）。

## 添加/移除流动性
- 添加：拥有者调用脚本或直接函数：
```
// 示例（脚本）：
forge script script/AddLiquidity.s.sol --rpc-url <YOUR_RPC> --broadcast \
  --with "TOKEN_ADDRESS=<DEPLOYED_TOKEN_ADDRESS> PRIVATE_KEY=<OWNER_PK>"
```
- 函数接口：`addLiquidityETH(tokenAmount, amountTokenMin, amountETHMin, deadlineSeconds)`，需附带 ETH。
- 移除：`removeLiquidity(liquidity, amountTokenMin, amountETHMin, deadlineSeconds)`。

## 常见问题
- `forge` 命令不存在：请先安装 Foundry 并将其加入 PATH。
- 交易未开放：调用 `enableTrading()`。
- 流动性路由地址：默认 UniswapV2 主网 Router `0x7a250d...`，测试网也通用，如需其他 DEX 可替换路由地址。

## 风险提示
- 税率与限额设置需兼顾公平与合规，避免过高税率导致用户体验差。
- 部署私钥与税钱包为敏感信息，请通过环境变量安全注入，勿硬编码。

