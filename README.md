# Tesseract Protocol

Tesseract Protocol facilitates fast, simple token swaps between **Avalanche Subnets (L1s)**

## Target Features

- Cross-L1 swaps for curated L1s, DEXes, and tokens
- Sub-10 second round-trip transactions to/from C-Chain
- No RPC switching required from source L1

## Prerequisites

- Home and Remote token deployments using [ICTT](https://github.com/ava-labs/avalanche-interchain-token-transfer)
- L1 RPCs
- Cell(s) deployed across chains
- Cross-L1 message relayer

## Architecture

Based on [Yak Swap](https://github.com/yieldyak/yak-aggregator), using onchain quote and swap functions with adapters for different DEXes.

- Similar to Yak Swap, clients should gather quotes by querying the RPCs, compare prices, generate a swap using the best quote and post the transaction.
- Different to Yak Swap, clients should consider that swaps are nonatomic (settled over multiple blocks) and the best quote may pass through a sub-optimal route in case the swap fails and funds fall back to a chain where the user does not have gas.


### Swap Failure Handling & Risks

**Warning:** Swaps on this protocol are **nonatomic** (they are not all-or-nothing). It is critical to understand the failure modes:

* **Single-Hop Rollback:**
    If a simple, direct swap fails, the transaction reverts. The **`sender`** receives their original **`tokenIn`** back on the **`sourceChain`**.

* **Multi-Hop Failure (Fund Forwarding):**
    If a swap fails mid-path (on an intermediate chain), the protocol **does not roll back**. Instead, the original **`tokenIn`** is forwarded to the **`receiver`**'s address on the **`chain where the trade failed`**.
    * **Risk:** In this multi-hop failure scenario, the original **`sender` does not get their funds back**. The funds are sent to the intended recipient, but on a different chain and in the *original* token, not the *expected* token.

## Important Notes

- Trust assumptions exist for L1 interactions
- `tokenIn` and `tokenOut` tokens used within a `path` must have ICTT deployments (for TokenHome and TokenRemote)
- Inherent risks in cross-L1 transactions, including relayer execution
- For full details on Avalanche's new L1 framework, refer to [ACP-77](https://github.com/avalanche-foundation/ACPs/blob/main/ACPs/77-reinventing-subnets/README.md).
