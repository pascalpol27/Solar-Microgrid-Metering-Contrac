# ⚡ Solar Microgrid Metering Contract

> 🌱 A decentralized smart contract system for fair energy distribution, consumption tracking, and surplus energy trading in community solar microgrids.

## 🔋 Overview

This Clarity smart contract enables precise energy usage tracking and billing for community solar systems. Residents can monitor consumption, generate surplus energy tokens, and participate in peer-to-peer energy trading within their microgrid community.

## ✨ Features

- 📊 **Smart Meter Integration**: Oracle-based energy consumption and generation logging
- 💰 **Automated Billing**: Fair, transparent billing system based on actual usage
- 🪙 **Surplus Energy Tokens**: Tokenize excess generation for community trading
- 🏘️ **Community Trading**: P2P energy token marketplace within the microgrid
- ⚖️ **Fair Distribution**: Encourages solar adoption and equitable energy sharing

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for transactions

### Deployment
```bash
clarinet deploy
```

## 📖 Usage Guide

### 👤 Resident Registration
```clarity
(contract-call? .solar-microgrid register-resident "John Doe")
```

### 🔧 Meter Installation
```clarity
(contract-call? .solar-microgrid install-meter u1 "123 Solar Street" u5000)
```

### 📈 Energy Reading (Oracle Only)
```clarity
(contract-call? .solar-microgrid log-energy-reading u1 u150 u200)
```

### 🧾 Billing Management
```clarity
;; Create monthly bill
(contract-call? .solar-microgrid create-billing-record 'SP1ABC...XYZ u202401)

;; Pay your bill
(contract-call? .solar-microgrid pay-bill u202401)
```

### 💸 Energy Trading
```clarity
;; Trade surplus tokens
(contract-call? .solar-microgrid trade-surplus-energy u100 'SP2DEF...ABC)

;; Redeem tokens for STX
(contract-call? .solar-microgrid redeem-surplus-tokens u50)
```

## 🔍 Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-resident` | Get resident profile and stats |
| `get-meter` | Retrieve meter information |
| `get-billing-record` | View billing history |
| `get-energy-reading` | Check specific energy readings |
| `get-contract-stats` | Overall system statistics |
| `get-surplus-balance` | Check surplus token balance |

## ⚙️ Contract Configuration

### Admin Functions
- `set-oracle`: Configure authorized oracle address
- `create-billing-record`: Generate billing records
- `update-meter-status`: Enable/disable meters

### Constants
- Energy Rate: 100 micro-STX per unit
- Surplus Token Rate: 80 tokens per generation unit
- Redemption Rate: 95% of market value

## 🛡️ Security Features

- Oracle-only energy logging
- Owner-restricted administrative functions
- Balance verification for all transactions
- Duplicate prevention mechanisms

## 📊 Token Economics

### Surplus Energy Token (SET)
- **Purpose**: Represent excess solar generation
- **Exchange**: Tradeable within community
- **Redemption**: Convert to STX at 95% rate
- **Minting**: Automatic when surplus is generated

## 🤝 Community Benefits

- 📉 **Lower Energy Costs**: Peer-to-peer trading reduces reliance on grid
- 🌿 **Sustainability**: Incentivizes renewable energy adoption  
- 🏆 **Fair Billing**: Pay only for actual consumption
- 💹 **Income Generation**: Monetize excess solar production
- 📱 **Transparency**: All transactions recorded on-chain

## 🔗 Integration

The contract supports oracle integration for real-time smart meter data feeds. Compatible with standard IoT energy monitoring devices and supports automated billing cycles.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Built with ❤️ for sustainable community energy solutions*
