;; Demand Response Coordination Contract
;; Manages demand response programs, participant coordination, and incentive distribution

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PARTICIPANT-NOT-FOUND (err u201))
(define-constant ERR-PARTICIPANT-ALREADY-EXISTS (err u202))
(define-constant ERR-PROGRAM-NOT-FOUND (err u203))
(define-constant ERR-PROGRAM-ALREADY-EXISTS (err u204))
(define-constant ERR-EVENT-NOT-FOUND (err u205))
(define-constant ERR-INVALID-REDUCTION-TARGET (err u206))
(define-constant ERR-INSUFFICIENT-FUNDS (err u207))
(define-constant ERR-EVENT-ALREADY-ACTIVE (err u208))
(define-constant ERR-INVALID-DURATION (err u209))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Program types
(define-constant PROGRAM-RESIDENTIAL "residential")
(define-constant PROGRAM-COMMERCIAL "commercial")
(define-constant PROGRAM-INDUSTRIAL "industrial")

;; Event status
(define-constant EVENT-SCHEDULED "scheduled")
(define-constant EVENT-ACTIVE "active")
(define-constant EVENT-COMPLETED "completed")
(define-constant EVENT-CANCELLED "cancelled")

;; Data structures
(define-map demand-response-programs
  { program-id: (string-ascii 32) }
  {
    name: (string-ascii 64),
    program-type: (string-ascii 16),
    base-incentive: uint,
    performance-bonus: uint,
    max-participants: uint,
    current-participants: uint,
    status: (string-ascii 16),
    created-at: uint
  }
)

(define-map program-participants
  { program-id: (string-ascii 32), participant: principal }
  {
    meter-id: (string-ascii 32),
    max-reduction-capacity: uint,
    baseline-consumption: uint,
    participation-score: uint,
    total-rewards: uint,
    joined-at: uint,
    status: (string-ascii 16)
  }
)

(define-map demand-response-events
  { event-id: (string-ascii 32) }
  {
    program-id: (string-ascii 32),
    target-reduction: uint,
    duration-blocks: uint,
    incentive-rate: uint,
    start-block: uint,
    end-block: uint,
    actual-reduction: uint,
    participants-count: uint,
    status: (string-ascii 16),
    created-by: principal
  }
)

(define-map event-participation
  { event-id: (string-ascii 32), participant: principal }
  {
    committed-reduction: uint,
    actual-reduction: uint,
    baseline-consumption: uint,
    reward-earned: uint,
    participation-confirmed: bool
  }
)

(define-map participant-rewards
  { participant: principal }
  {
    total-earned: uint,
    total-claimed: uint,
    pending-rewards: uint,
    participation-events: uint
  }
)

;; Contract variables
(define-data-var total-programs uint u0)
(define-data-var total-events uint u0)
(define-data-var total-participants uint u0)
(define-data-var reward-pool uint u0)

;; Program management functions
(define-public (create-program
  (program-id (string-ascii 32))
  (name (string-ascii 64))
  (program-type (string-ascii 16))
  (base-incentive uint)
  (performance-bonus uint)
  (max-participants uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? demand-response-programs { program-id: program-id })) ERR-PROGRAM-ALREADY-EXISTS)
    (asserts! (> base-incentive u0) ERR-INVALID-REDUCTION-TARGET)

    (map-set demand-response-programs
      { program-id: program-id }
      {
        name: name,
        program-type: program-type,
        base-incentive: base-incentive,
        performance-bonus: performance-bonus,
        max-participants: max-participants,
        current-participants: u0,
        status: "active",
        created-at: block-height
      }
    )

    (var-set total-programs (+ (var-get total-programs) u1))
    (ok program-id)
  )
)

(define-public (join-program
  (program-id (string-ascii 32))
  (meter-id (string-ascii 32))
  (max-reduction-capacity uint)
  (baseline-consumption uint))
  (let
    (
      (program-data (unwrap! (map-get? demand-response-programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND))
      (existing-participation (map-get? program-participants { program-id: program-id, participant: tx-sender }))
    )
    (asserts! (is-none existing-participation) ERR-PARTICIPANT-ALREADY-EXISTS)
    (asserts! (< (get current-participants program-data) (get max-participants program-data)) ERR-NOT-AUTHORIZED)
    (asserts! (> max-reduction-capacity u0) ERR-INVALID-REDUCTION-TARGET)

    (map-set program-participants
      { program-id: program-id, participant: tx-sender }
      {
        meter-id: meter-id,
        max-reduction-capacity: max-reduction-capacity,
        baseline-consumption: baseline-consumption,
        participation-score: u100,
        total-rewards: u0,
        joined-at: block-height,
        status: "active"
      }
    )

    ;; Update program participant count
    (map-set demand-response-programs
      { program-id: program-id }
      (merge program-data { current-participants: (+ (get current-participants program-data) u1) })
    )

    ;; Initialize participant rewards
    (map-set participant-rewards
      { participant: tx-sender }
      (merge
        (default-to { total-earned: u0, total-claimed: u0, pending-rewards: u0, participation-events: u0 }
          (map-get? participant-rewards { participant: tx-sender }))
        { participation-events: (+
          (default-to u0 (get participation-events (map-get? participant-rewards { participant: tx-sender })))
          u0) }
      )
    )

    (var-set total-participants (+ (var-get total-participants) u1))
    (ok true)
  )
)

;; Event management functions
(define-public (create-demand-response-event
  (event-id (string-ascii 32))
  (program-id (string-ascii 32))
  (target-reduction uint)
  (duration-blocks uint)
  (incentive-rate uint)
  (start-block uint))
  (let
    (
      (program-data (unwrap! (map-get? demand-response-programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND))
      (end-block (+ start-block duration-blocks))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? demand-response-events { event-id: event-id })) ERR-EVENT-ALREADY-ACTIVE)
    (asserts! (> target-reduction u0) ERR-INVALID-REDUCTION-TARGET)
    (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
    (asserts! (> start-block block-height) ERR-INVALID-DURATION)

    (map-set demand-response-events
      { event-id: event-id }
      {
        program-id: program-id,
        target-reduction: target-reduction,
        duration-blocks: duration-blocks,
        incentive-rate: incentive-rate,
        start-block: start-block,
        end-block: end-block,
        actual-reduction: u0,
        participants-count: u0,
        status: EVENT-SCHEDULED,
        created-by: tx-sender
      }
    )

    (var-set total-events (+ (var-get total-events) u1))
    (ok event-id)
  )
)

(define-public (participate-in-event
  (event-id (string-ascii 32))
  (committed-reduction uint))
  (let
    (
      (event-data (unwrap! (map-get? demand-response-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (program-id (get program-id event-data))
      (participant-data (unwrap! (map-get? program-participants { program-id: program-id, participant: tx-sender }) ERR-PARTICIPANT-NOT-FOUND))
    )
    (asserts! (is-eq (get status event-data) EVENT-SCHEDULED) ERR-NOT-AUTHORIZED)
    (asserts! (<= committed-reduction (get max-reduction-capacity participant-data)) ERR-INVALID-REDUCTION-TARGET)
    (asserts! (> committed-reduction u0) ERR-INVALID-REDUCTION-TARGET)

    (map-set event-participation
      { event-id: event-id, participant: tx-sender }
      {
        committed-reduction: committed-reduction,
        actual-reduction: u0,
        baseline-consumption: (get baseline-consumption participant-data),
        reward-earned: u0,
        participation-confirmed: true
      }
    )

    ;; Update event participants count
    (map-set demand-response-events
      { event-id: event-id }
      (merge event-data { participants-count: (+ (get participants-count event-data) u1) })
    )

    (ok committed-reduction)
  )
)

(define-public (record-actual-reduction
  (event-id (string-ascii 32))
  (participant principal)
  (actual-reduction uint))
  (let
    (
      (event-data (unwrap! (map-get? demand-response-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (participation-data (unwrap! (map-get? event-participation { event-id: event-id, participant: participant }) ERR-PARTICIPANT-NOT-FOUND))
      (reward-calculation (calculate-reward event-data participation-data actual-reduction))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status event-data) EVENT-ACTIVE) ERR-NOT-AUTHORIZED)

    ;; Update participation record
    (map-set event-participation
      { event-id: event-id, participant: participant }
      (merge participation-data {
        actual-reduction: actual-reduction,
        reward-earned: reward-calculation
      })
    )

    ;; Update participant rewards
    (update-participant-rewards participant reward-calculation)

    (ok reward-calculation)
  )
)

;; Reward calculation and distribution
(define-private (calculate-reward (event-data (tuple (program-id (string-ascii 32)) (target-reduction uint) (duration-blocks uint) (incentive-rate uint) (start-block uint) (end-block uint) (actual-reduction uint) (participants-count uint) (status (string-ascii 16)) (created-by principal))) (participation-data (tuple (committed-reduction uint) (actual-reduction uint) (baseline-consumption uint) (reward-earned uint) (participation-confirmed bool))) (actual-reduction uint))
  (let
    (
      (base-reward (* actual-reduction (get incentive-rate event-data)))
      (performance-ratio (if (> (get committed-reduction participation-data) u0)
        (/ (* actual-reduction u100) (get committed-reduction participation-data))
        u0))
      (performance-bonus (if (>= performance-ratio u100)
        (/ base-reward u10) ;; 10% bonus for meeting commitment
        u0))
    )
    (+ base-reward performance-bonus)
  )
)

(define-private (update-participant-rewards (participant principal) (reward-amount uint))
  (let
    (
      (current-rewards (default-to
        { total-earned: u0, total-claimed: u0, pending-rewards: u0, participation-events: u0 }
        (map-get? participant-rewards { participant: participant })))
    )
    (map-set participant-rewards
      { participant: participant }
      {
        total-earned: (+ (get total-earned current-rewards) reward-amount),
        total-claimed: (get total-claimed current-rewards),
        pending-rewards: (+ (get pending-rewards current-rewards) reward-amount),
        participation-events: (+ (get participation-events current-rewards) u1)
      }
    )
  )
)

(define-public (claim-rewards)
  (let
    (
      (reward-data (unwrap! (map-get? participant-rewards { participant: tx-sender }) ERR-PARTICIPANT-NOT-FOUND))
      (pending-amount (get pending-rewards reward-data))
    )
    (asserts! (> pending-amount u0) ERR-INSUFFICIENT-FUNDS)

    ;; Update reward record
    (map-set participant-rewards
      { participant: tx-sender }
      (merge reward-data {
        total-claimed: (+ (get total-claimed reward-data) pending-amount),
        pending-rewards: u0
      })
    )

    ;; In a real implementation, this would transfer tokens
    (ok pending-amount)
  )
)

;; Read-only functions
(define-read-only (get-program-info (program-id (string-ascii 32)))
  (map-get? demand-response-programs { program-id: program-id })
)

(define-read-only (get-participant-info (program-id (string-ascii 32)) (participant principal))
  (map-get? program-participants { program-id: program-id, participant: participant })
)

(define-read-only (get-event-info (event-id (string-ascii 32)))
  (map-get? demand-response-events { event-id: event-id })
)

(define-read-only (get-event-participation (event-id (string-ascii 32)) (participant principal))
  (map-get? event-participation { event-id: event-id, participant: participant })
)

(define-read-only (get-participant-rewards (participant principal))
  (map-get? participant-rewards { participant: participant })
)

(define-read-only (get-total-programs)
  (var-get total-programs)
)

(define-read-only (get-total-events)
  (var-get total-events)
)

(define-read-only (get-total-participants)
  (var-get total-participants)
)

;; Event status management
(define-public (activate-event (event-id (string-ascii 32)))
  (let
    (
      (event-data (unwrap! (map-get? demand-response-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status event-data) EVENT-SCHEDULED) ERR-NOT-AUTHORIZED)
    (asserts! (>= block-height (get start-block event-data)) ERR-NOT-AUTHORIZED)

    (map-set demand-response-events
      { event-id: event-id }
      (merge event-data { status: EVENT-ACTIVE })
    )
    (ok true)
  )
)

(define-public (complete-event (event-id (string-ascii 32)) (total-actual-reduction uint))
  (let
    (
      (event-data (unwrap! (map-get? demand-response-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status event-data) EVENT-ACTIVE) ERR-NOT-AUTHORIZED)
    (asserts! (>= block-height (get end-block event-data)) ERR-NOT-AUTHORIZED)

    (map-set demand-response-events
      { event-id: event-id }
      (merge event-data {
        status: EVENT-COMPLETED,
        actual-reduction: total-actual-reduction
      })
    )
    (ok total-actual-reduction)
  )
)
