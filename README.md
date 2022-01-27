# Rentable Protocol

The Rental Protocol for NFTs

## Beta Deployment (Mainnet)

Deployer: 0xf6798a60B576658461eeFebf583C2AaECD732334

Governance: 0xC08618375bb20ac1C4BB806Baa027a4362156fE6

Operator: 0x49941c694693371894d6DCc1AbDbC91A7395b703

FeeCollector: 0xa55D576DE85dA4295aBc1E2BEa5d5c77Fe189205

ProxyFactory: 0x3CEB8096585D31810082553644B73B2D147E0Adb

Meebits: 0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7

YRentable: 0xf83240Ac233d68ED7472F6bc4941C6d89b1eCBB8

ORentable: 0xEeCd120f88496cD845F3776a1cc358D29aF30827

WRentable: 0x1Bb86a46a9d2b64ac48D762C13BEbB6531c67c40

Rentable: 0xB1d46a10CD78776E61B1475bf73886Ff48aA6922

## Requirements

To run the project you need:

- Python 3.8 local development environment and Node.js 10.x development environment for Ganache.
- Brownie local environment setup. See instructions for how to install it
  [here](https://eth-brownie.readthedocs.io/en/stable/install.html).

## Installation

To use the tools that this project provides, please pull the repository from GitHub
and install its dependencies as follows.
You will need [yarn](https://yarnpkg.com/lang/en/docs/install/) installed.
It is recommended to use a Python virtual environment.

```bash
git clone https://github.com/rent-fi/n
cd n
yarn install --lock-file
pip install -r requirements-dev.txt
```

## Usage

1. Choose network
2. Deploy contracts (or use already deployed ones)
3. Prepare your account
4. Use network console

Remember to [add](https://metamask.zendesk.com/hc/en-us/articles/360043227612-How-to-add-a-custom-network-RPC) the network to your Metamask

### Network

Run the following commands respectively and keep the session open. Network is ephemeral, when you close the command you reset it.

#### Local Testnet 

```bash
yarn network:testnet
```

#### Mainnet Fork

Useful to interact with other protocols in mainnet via a local fork.

You need local env variables for [Etherscan API](https://etherscan.io/apis) and [Infura](https://infura.io/) (`ETHERSCAN_TOKEN` `WEB3_INFURA_PROJECT_ID`). 

Set them in `.env` file following `.env.example`

```bash
yarn network:mainnet-fork
```

### Deploy contracts

```bash
yarn deploy
```

### Prepare your account

Mint some NFT to your account

```bash
yarn mintNFT
```

### Use network console

Run the console
```bash
yarn console
```

and interact directly with contracts

Example: Check owner of `tokenId = 4` for NFT with smart contract address `0x734f99154988a737ae7159594Ebf828eB6761645`

```python
>>> t = TestNFT.at('0x734f99154988a737ae7159594Ebf828eB6761645')
>>> t.ownerOf(4)
'0x5898D8D9a8895dBBd3d035724FA1Bc252876cC22'
>>>
```