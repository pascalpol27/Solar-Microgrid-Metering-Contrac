(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-RESIDENT-NOT-FOUND u404)
(define-constant ERR-METER-NOT-FOUND u405)
(define-constant ERR-INSUFFICIENT-FUNDS u406)
(define-constant ERR-INVALID-AMOUNT u407)
(define-constant ERR-ALREADY-EXISTS u408)
(define-constant ERR-ORACLE-NOT-AUTHORIZED u409)
(define-constant ENERGY-RATE u100)
(define-constant SURPLUS-TOKEN-RATE u80)

(define-fungible-token surplus-energy)

(define-data-var total-residents uint u0)
(define-data-var total-meters uint u0)
(define-data-var oracle-address (optional principal) none)
(define-data-var grid-balance uint u0)

(define-map residents 
  principal 
  {
    name: (string-ascii 50),
    registered-at: uint,
    total-consumed: uint,
    total-generated: uint,
    balance: uint,
    meter-id: uint
  }
)

(define-map meters 
  uint 
  {
    owner: principal,
    location: (string-ascii 100),
    capacity: uint,
    installed-at: uint,
    last-reading: uint,
    total-consumption: uint,
    total-generation: uint,
    active: bool
  }
)

(define-map billing-records 
  {resident: principal, period: uint} 
  {
    consumption: uint,
    generation: uint,
    cost: uint,
    surplus-tokens: uint,
    paid: bool,
    created-at: uint
  }
)

(define-map energy-readings 
  {meter-id: uint, timestamp: uint} 
  {
    consumption: uint,
    generation: uint,
    reported-by: principal
  }
)

(define-public (set-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err ERR-NOT-AUTHORIZED))
    (var-set oracle-address (some oracle))
    (ok true)
  )
)

(define-public (register-resident (name (string-ascii 50)))
  (let 
    (
      (current-count (var-get total-residents))
      (new-meter-id (+ (var-get total-meters) u1))
    )
    (asserts! (is-none (map-get? residents tx-sender)) (err ERR-ALREADY-EXISTS))
    (map-set residents tx-sender {
      name: name,
      registered-at: stacks-block-height,
      total-consumed: u0,
      total-generated: u0,
      balance: u0,
      meter-id: new-meter-id
    })
    (map-set meters new-meter-id {
      owner: tx-sender,
      location: "",
      capacity: u0,
      installed-at: stacks-block-height,
      last-reading: u0,
      total-consumption: u0,
      total-generation: u0,
      active: true
    })
    (var-set total-residents (+ current-count u1))
    (var-set total-meters new-meter-id)
    (ok new-meter-id)
  )
)

(define-public (install-meter (meter-id uint) (location (string-ascii 100)) (capacity uint))
  (let ((meter-data (unwrap! (map-get? meters meter-id) (err ERR-METER-NOT-FOUND))))
    (asserts! (is-eq tx-sender (get owner meter-data)) (err ERR-NOT-AUTHORIZED))
    (map-set meters meter-id (merge meter-data {
      location: location,
      capacity: capacity,
      active: true
    }))
    (ok true)
  )
)

(define-public (log-energy-reading (meter-id uint) (consumption uint) (generation uint))
  (let 
    (
      (meter-data (unwrap! (map-get? meters meter-id) (err ERR-METER-NOT-FOUND)))
      (oracle (unwrap! (var-get oracle-address) (err ERR-ORACLE-NOT-AUTHORIZED)))
      (current-time stacks-block-height)
    )
    (asserts! (is-eq tx-sender oracle) (err ERR-ORACLE-NOT-AUTHORIZED))
    (asserts! (get active meter-data) (err ERR-METER-NOT-FOUND))
    (asserts! (> consumption u0) (err ERR-INVALID-AMOUNT))
    
    (map-set energy-readings 
      {meter-id: meter-id, timestamp: current-time}
      {
        consumption: consumption,
        generation: generation,
        reported-by: tx-sender
      }
    )
    
    (map-set meters meter-id (merge meter-data {
      last-reading: current-time,
      total-consumption: (+ (get total-consumption meter-data) consumption),
      total-generation: (+ (get total-generation meter-data) generation)
    }))
    
    (try! (update-resident-consumption (get owner meter-data) consumption generation))
    (ok true)
  )
)

(define-public (create-billing-record (resident principal) (period uint))
  (let 
    (
      (resident-data (unwrap! (map-get? residents resident) (err ERR-RESIDENT-NOT-FOUND)))
      (meter-id (get meter-id resident-data))
      (meter-data (unwrap! (map-get? meters meter-id) (err ERR-METER-NOT-FOUND)))
      (consumption (get total-consumption meter-data))
      (generation (get total-generation meter-data))
      (cost (* consumption ENERGY-RATE))
      (surplus-tokens (* generation SURPLUS-TOKEN-RATE))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) (err ERR-NOT-AUTHORIZED))
    (asserts! (is-none (map-get? billing-records {resident: resident, period: period})) (err ERR-ALREADY-EXISTS))
    
    (map-set billing-records 
      {resident: resident, period: period}
      {
        consumption: consumption,
        generation: generation,
        cost: cost,
        surplus-tokens: surplus-tokens,
        paid: false,
        created-at: stacks-block-height
      }
    )
    
    (if (> surplus-tokens u0)
      (try! (ft-mint? surplus-energy surplus-tokens resident))
      true
    )
    
    (ok {cost: cost, surplus-tokens: surplus-tokens})
  )
)

(define-public (pay-bill (period uint))
  (let 
    (
      (billing-key {resident: tx-sender, period: period})
      (bill (unwrap! (map-get? billing-records billing-key) (err ERR-RESIDENT-NOT-FOUND)))
      (cost (get cost bill))
    )
    (asserts! (not (get paid bill)) (err ERR-ALREADY-EXISTS))
    (asserts! (>= (stx-get-balance tx-sender) cost) (err ERR-INSUFFICIENT-FUNDS))
    
    (try! (stx-transfer? cost tx-sender CONTRACT-OWNER))
    (map-set billing-records billing-key (merge bill {paid: true}))
    (var-set grid-balance (+ (var-get grid-balance) cost))
    (ok true)
  )
)

(define-public (trade-surplus-energy (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (try! (ft-transfer? surplus-energy amount tx-sender recipient))
    (ok true)
  )
)

(define-public (redeem-surplus-tokens (amount uint))
  (let ((stx-amount (/ (* amount u95) u100)))
    (asserts! (> amount u0) (err ERR-INVALID-AMOUNT))
    (asserts! (>= (var-get grid-balance) stx-amount) (err ERR-INSUFFICIENT-FUNDS))
    
    (try! (ft-burn? surplus-energy amount tx-sender))
    (try! (stx-transfer? stx-amount CONTRACT-OWNER tx-sender))
    (var-set grid-balance (- (var-get grid-balance) stx-amount))
    (ok stx-amount)
  )
)

(define-public (update-meter-status (meter-id uint) (active bool))
  (let ((meter-data (unwrap! (map-get? meters meter-id) (err ERR-METER-NOT-FOUND))))
    (asserts! (is-eq tx-sender (get owner meter-data)) (err ERR-NOT-AUTHORIZED))
    (map-set meters meter-id (merge meter-data {active: active}))
    (ok true)
  )
)

(define-public (add-balance (amount uint))
  (let ((resident-data (unwrap! (map-get? residents tx-sender) (err ERR-RESIDENT-NOT-FOUND))))
    (asserts! (>= (stx-get-balance tx-sender) amount) (err ERR-INSUFFICIENT-FUNDS))
    (try! (stx-transfer? amount tx-sender CONTRACT-OWNER))
    (map-set residents tx-sender (merge resident-data {
      balance: (+ (get balance resident-data) amount)
    }))
    (ok true)
  )
)

(define-private (update-resident-consumption (resident principal) (consumption uint) (generation uint))
  (let ((resident-data (unwrap! (map-get? residents resident) (err ERR-RESIDENT-NOT-FOUND))))
    (map-set residents resident (merge resident-data {
      total-consumed: (+ (get total-consumed resident-data) consumption),
      total-generated: (+ (get total-generated resident-data) generation)
    }))
    (ok true)
  )
)

(define-read-only (get-resident (resident principal))
  (map-get? residents resident)
)

(define-read-only (get-meter (meter-id uint))
  (map-get? meters meter-id)
)

(define-read-only (get-billing-record (resident principal) (period uint))
  (map-get? billing-records {resident: resident, period: period})
)

(define-read-only (get-energy-reading (meter-id uint) (timestamp uint))
  (map-get? energy-readings {meter-id: meter-id, timestamp: timestamp})
)

(define-read-only (get-contract-stats)
  {
    total-residents: (var-get total-residents),
    total-meters: (var-get total-meters),
    grid-balance: (var-get grid-balance),
    oracle-address: (var-get oracle-address)
  }
)

(define-read-only (get-surplus-balance (account principal))
  (ft-get-balance surplus-energy account)
)

(define-read-only (get-total-surplus-supply)
  (ft-get-supply surplus-energy)
)
