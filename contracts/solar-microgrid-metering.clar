;; Solar Microgrid Metering Smart Contract
;; Tracks energy production, consumption, and billing for solar microgrid participants

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-METER-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-RATE (err u104))
(define-constant ERR-METER-ALREADY-EXISTS (err u105))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data variables
(define-data-var energy-rate uint u50) ;; Rate per kWh in microSTX (0.00005 STX)
(define-data-var total-energy-produced uint u0)
(define-data-var total-energy-consumed uint u0)

;; Data maps
(define-map energy-meters principal {
    production: uint,
    consumption: uint,
    balance: int,
    last-reading-block: uint,
    is-active: bool
})

(define-map billing-history {meter: principal, block-height: uint} {
    energy-produced: uint,
    energy-consumed: uint,
    net-amount: int,
    rate-applied: uint
})

;; Read-only functions

(define-read-only (get-energy-rate)
    (var-get energy-rate)
)

(define-read-only (get-total-stats)
    {
        total-produced: (var-get total-energy-produced),
        total-consumed: (var-get total-energy-consumed),
        current-rate: (var-get energy-rate)
    }
)

(define-read-only (get-meter-info (meter principal))
    (map-get? energy-meters meter)
)

(define-read-only (get-meter-balance (meter principal))
    (match (map-get? energy-meters meter)
        meter-data (ok (get balance meter-data))
        ERR-METER-NOT-FOUND
    )
)

(define-read-only (get-billing-record (meter principal) (block-height-param uint))
    (map-get? billing-history {meter: meter, block-height: block-height-param})
)

(define-read-only (calculate-energy-cost (kwh-amount uint))
    (ok (* kwh-amount (var-get energy-rate)))
)

;; Public functions

(define-public (register-meter (meter principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? energy-meters meter)) ERR-METER-ALREADY-EXISTS)
        
        (map-set energy-meters meter {
            production: u0,
            consumption: u0,
            balance: 0,
            last-reading-block: stacks-block-height,
            is-active: true
        })
        
        (ok true)
    )
)

(define-public (record-energy-production (meter principal) (kwh-produced uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> kwh-produced u0) ERR-INVALID-AMOUNT)
        
        (match (map-get? energy-meters meter)
            meter-data 
            (let ((energy-value (/ (* kwh-produced (var-get energy-rate)) u1000000)))
                (map-set energy-meters meter (merge meter-data {
                    production: (+ (get production meter-data) kwh-produced),
                    balance: (+ (get balance meter-data) (to-int energy-value)),
                    last-reading-block: stacks-block-height
                }))
                
                (map-set billing-history {meter: meter, block-height: stacks-block-height} {
                    energy-produced: kwh-produced,
                    energy-consumed: u0,
                    net-amount: (to-int energy-value),
                    rate-applied: (var-get energy-rate)
                })
                
                (var-set total-energy-produced (+ (var-get total-energy-produced) kwh-produced))
                (ok true)
            )
            ERR-METER-NOT-FOUND
        )
    )
)

(define-public (record-energy-consumption (meter principal) (kwh-consumed uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> kwh-consumed u0) ERR-INVALID-AMOUNT)
        
        (match (map-get? energy-meters meter)
            meter-data 
            (let ((energy-cost (/ (* kwh-consumed (var-get energy-rate)) u1000000)))
                (asserts! (>= (get balance meter-data) (to-int energy-cost)) ERR-INSUFFICIENT-BALANCE)
                
                (map-set energy-meters meter (merge meter-data {
                    consumption: (+ (get consumption meter-data) kwh-consumed),
                    balance: (- (get balance meter-data) (to-int energy-cost)),
                    last-reading-block: stacks-block-height
                }))
                
                (map-set billing-history {meter: meter, block-height: stacks-block-height} {
                    energy-produced: u0,
                    energy-consumed: kwh-consumed,
                    net-amount: (- 0 (to-int energy-cost)),
                    rate-applied: (var-get energy-rate)
                })
                
                (var-set total-energy-consumed (+ (var-get total-energy-consumed) kwh-consumed))
                (ok true)
            )
            ERR-METER-NOT-FOUND
        )
    )
)

(define-public (set-energy-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> new-rate u0) ERR-INVALID-RATE)
        
        (var-set energy-rate new-rate)
        (ok true)
    )
)

(define-public (deactivate-meter (meter principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (match (map-get? energy-meters meter)
            meter-data 
            (begin
                (map-set energy-meters meter (merge meter-data {is-active: false}))
                (ok true)
            )
            ERR-METER-NOT-FOUND
        )
    )
)

(define-public (reactivate-meter (meter principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (match (map-get? energy-meters meter)
            meter-data 
            (begin
                (map-set energy-meters meter (merge meter-data {is-active: true}))
                (ok true)
            )
            ERR-METER-NOT-FOUND
        )
    )
)

;; Settlement function for monthly billing cycles
(define-public (settle-billing-period (meter principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (match (map-get? energy-meters meter)
            meter-data 
            (let ((current-balance (get balance meter-data)))
                (if (> current-balance 0)
                    ;; Positive balance - meter has credit
                    (begin
                        (map-set billing-history {meter: meter, block-height: stacks-block-height} {
                            energy-produced: u0,
                            energy-consumed: u0,
                            net-amount: current-balance,
                            rate-applied: (var-get energy-rate)
                        })
                        (ok {settlement-type: "credit", amount: current-balance})
                    )
                    ;; Negative balance - meter owes money
                    (ok {settlement-type: "debit", amount: current-balance})
                )
            )
            ERR-METER-NOT-FOUND
        )
    )
)
