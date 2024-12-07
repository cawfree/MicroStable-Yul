# MicroStable-Yul

A [**Standalone Yul**](https://docs.soliditylang.org/en/latest/yul.html) implementation of [**shafu0x**](https://x.com/shafu0x)'s [**MicroStable**](https://github.com/shafu0x/MicroStable), a minimum viable stablecoin based loosely on [**DYAD**](https://github.com/DyadStablecoin/contracts).

This is a submission to [**MicroStable World**](https://github.com/shafu0x/MicroStable-World) 🌍!

### 🚀 Getting Started

This project uses [**Foundry**](https://getfoundry.sh/).

```sh
git clone https://github.com/cawfree/MicroStable-Yul
cd MicroStable-Yul
forge install

# Currently Foundry may only build one Yul file at a time,
# so we build these here manually. To run tests, the Yul
# bytecode is manually parsed from the `out/` directory,
# requiring a call to `vm.ffi`.
forge build src/Manager.yul
forge build src/ShUSD.yul
forge test --ffi
```

## 🙏 Made possible thanks to

- [`foundry-yul`](https://github.com/CodeForcer/foundry-yul)
- [`erc721Yul`](https://github.com/0xfabdav/erc721Yul)

## ✌️ License
[**CC0-1.0**](LICENSE)
