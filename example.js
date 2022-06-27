> const casino = await hre.ethers.getContract('Exotic');
> await casino.nextRaceId()
BigNumber { _hex: '0x62ba2d10', _isBigNumber: true }
> 0x62ba2d10
1656368400
> await casino.placeBet(0x62ba2d10, [0], {value: ethers.utils.parseEther('0.01')})
{
  hash: '0xc548ea72084e41f68c3e60f973e4d37f142cf9c00415aa7e9d0902bbd0a3f8a8',
  type: 0,
  accessList: null,
  blockHash: '0xb7119a38319e577b26c24485d6bde382cb8a9fdf0789bff5d17669c48fda394b',
  blockNumber: 11027503,
  transactionIndex: 2,
  confirmations: 1,
  from: '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE',
  gasPrice: BigNumber { _hex: '0x060db88400', _isBigNumber: true },
  gasLimit: BigNumber { _hex: '0x03483e', _isBigNumber: true },
  to: '0xE3AB16102aCDf52DD5bA49aE98102844e0E1E7c0',
  value: BigNumber { _hex: '0x2386f26fc10000', _isBigNumber: true },
  nonce: 68,
  data: '0x30d146550000000000000000000000000000000000000000000000000000000062ba2d10000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000',
  r: '0x475e540730fbca7f407a22c82c2394d969508c52d9d0a8fe6e871f2af7d91e4a',
  s: '0x0171b4fd0a49eaabfb215cb430d9be69ef8b3019dc89f4122416bd1ffa2e5ec9',
  v: 86262,
  creates: null,
  chainId: 43113,
  wait: [Function (anonymous)]
}
> await casino.odds(0x62ba2d10, [0])
BigNumber { _hex: '0x02540be400', _isBigNumber: true }
> 0x02540be400
10000000000
> await casino.placeBet(0x62ba2d10, [1], {value: ethers.utils.parseEther('0.01')})
{
  hash: '0xf361fa0e6f1a445b1f74d733e0799799dff16d8f368e848d34d4d9b59cc89c7c',
  type: 0,
  accessList: null,
  blockHash: null,
  blockNumber: null,
  transactionIndex: null,
  confirmations: 0,
  from: '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE',
  gasPrice: BigNumber { _hex: '0x060db88400', _isBigNumber: true },
  gasLimit: BigNumber { _hex: '0x02cda2', _isBigNumber: true },
  to: '0xE3AB16102aCDf52DD5bA49aE98102844e0E1E7c0',
  value: BigNumber { _hex: '0x2386f26fc10000', _isBigNumber: true },
  nonce: 69,
  data: '0x30d146550000000000000000000000000000000000000000000000000000000062ba2d10000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001',
  r: '0x0e0deac908f258cd5e2ce44c453b3204a34d43f133f34fc479514a8a43ab7efc',
  s: '0x0cc66f1c2e4a908e0192055e763c9575dcb93861fe3897e6bbcf995c82bd11f9',
  v: 86262,
  creates: null,
  chainId: 43113,
  wait: [Function (anonymous)]
}
> await casino.odds(0x62ba2d10, [0])
BigNumber { _hex: '0x012a05f200', _isBigNumber: true }
> 0x012a05f200
5000000000
> // Now I waited 10 minutes
> await casino.endRace(0x62ba2d10);
{
  hash: '0xc315695aabb1708c26d7d02bf26f72efdc9dddb5371a89279df3a58cb14ebe2b',
  type: 0,
  accessList: null,
  blockHash: null,
  blockNumber: null,
  transactionIndex: null,
  confirmations: 0,
  from: '0x1604F1c0aF9765D940519cd2593292b3cE3Ba3CE',
  gasPrice: BigNumber { _hex: '0x060db88400', _isBigNumber: true },
  gasLimit: BigNumber { _hex: '0x018946', _isBigNumber: true },
  to: '0xE3AB16102aCDf52DD5bA49aE98102844e0E1E7c0',
  value: BigNumber { _hex: '0x00', _isBigNumber: true },
  nonce: 70,
  data: '0x052608c90000000000000000000000000000000000000000000000000000000062ba2d10',
  r: '0x7ed4ca0d9c8f5f8be9f89e446de150163f888bb00a0f28be9182007d160e5cbb',
  s: '0x12ebeae2e3e91e20776e99f32a11bbfc68c5accd38bfb29a820fed32a56a274d',
  v: 86261,
  creates: null,
  chainId: 43113,
  wait: [Function (anonymous)]
}
