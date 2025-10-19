import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensure contract can be deployed and initialized",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        
        let block = chain.mineBlock([]);
        assertEquals(block.receipts.length, 0);
        assertEquals(block.height, 2);
    },
});

Clarinet.test({
    name: "Test meter registration functionality",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("solar-microgrid-metering", "register-meter", [
                types.principal(wallet_1.address)
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 1);
        assertEquals(block.receipts[0].result.expectOk(), types.bool(true));
    },
});

Clarinet.test({
    name: "Test energy production recording",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get("deployer")!;
        const wallet_1 = accounts.get("wallet_1")!;
        
        let block = chain.mineBlock([
            Tx.contractCall("solar-microgrid-metering", "register-meter", [
                types.principal(wallet_1.address)
            ], deployer.address),
            Tx.contractCall("solar-microgrid-metering", "record-energy-production", [
                types.principal(wallet_1.address),
                types.uint(100) // 100 kWh
            ], deployer.address)
        ]);
        
        assertEquals(block.receipts.length, 2);
        assertEquals(block.receipts[1].result.expectOk(), types.bool(true));
    },
});
