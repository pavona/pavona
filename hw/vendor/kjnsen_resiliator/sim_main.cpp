#include <signal.h>
#include <limits.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <linux/mman.h>
#include <fcntl.h>
#include <errno.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>

#define STRINGIFY(x) STRINGIFY_(x)
#define STRINGIFY_(x) #x

#define CONCAT2(a, b) CONCAT2_(a, b)
#define CONCAT2_(a, b) a ## b
#define CONCAT3(a, b, c) CONCAT3_(a, b, c)
#define CONCAT3_(a, b, c) a ## b ## c

#define PATH_CONCAT(a, b) a/b

#define EMPTY_MACRO 1
#define IS_EMPTY(macro) (CONCAT3(EMPTY_, MACRO, macro) == EMPTY_MACRO)

#if !defined(TOP_NAME) || IS_EMPTY(TOP_NAME)
#error Macro TOP_NAME must be defined! Set it in hw_config.cfg.
#endif

#if !defined(START_RESET_CYCLE) || IS_EMPTY(START_RESET_CYCLE)
#error Macro START_RESET_CYCLE must be defined! Set it in tb_config.cfg.
#endif

#if !defined(RESET_DURATION) || IS_EMPTY(RESET_DURATION)
#error Macro RESET_DURATION must be defined! Set it in tb_config.cfg.
#endif

#define END_RESET_CYCLE (START_RESET_CYCLE + RESET_DURATION)

#if !defined(HASH_CACHE_BUCKET_ELEMS_LIMIT) || IS_EMPTY(HASH_CACHE_BUCKET_ELEMS_LIMIT)
#error Macro HASH_CACHE_BUCKET_ELEMS_LIMIT must be defined! Set it in tb_config.cfg.
#endif

// Maximum number of elements per bucket list of the hash cache
// Must be positive and a power of 2
static_assert(HASH_CACHE_BUCKET_ELEMS_LIMIT > 0 &&
  (HASH_CACHE_BUCKET_ELEMS_LIMIT & (HASH_CACHE_BUCKET_ELEMS_LIMIT - 1)) == 0,
  "HASH_CACHE_BUCKET_ELEMS_LIMIT must be positive and a power of 2!");

#if !defined(HASHING_PERIODICITY) || IS_EMPTY(HASHING_PERIODICITY)
#error Macro HASHING_PERIODICITY must be defined! Set it in tb_config.cfg.
#endif

#if !defined(NUM_ENTRIES_HASH_CACHE_POWER) || IS_EMPTY(NUM_ENTRIES_HASH_CACHE_POWER)
#error Macro NUM_ENTRIES_HASH_CACHE_POWER must be defined! Set it in tb_config.cfg.
#endif

#define NUM_ENTRIES_HASH_CACHE (1ULL << NUM_ENTRIES_HASH_CACHE_POWER)

#if !defined(NUM_ENTRIES_SAME_RES_LIST) || IS_EMPTY(NUM_ENTRIES_SAME_RES_LIST)
#error Macro NUM_ENTRIES_SAME_RES_LIST must be defined! Set it in tb_config.cfg.
#endif

#if !defined(NUM_BLOCKS_FACTOR_SAME_RES_LIST) || IS_EMPTY(NUM_BLOCKS_FACTOR_SAME_RES_LIST)
#error Macro NUM_BLOCKS_FACTOR_SAME_RES_LIST must be defined! Set it in tb_config.cfg.
#endif

#if !defined(NPROC) || IS_EMPTY(NPROC)
#error Macro NPROC must be defined! Did you not use the Makefile to compile? \
       Alternatively use -D NPROC=`nproc` during compilation!
#endif

#define NUM_BLOCKS_SAME_RES_LIST (NUM_BLOCKS_FACTOR_SAME_RES_LIST * NPROC)

#if !defined(OUT_DIR) || IS_EMPTY(OUT_DIR)
#error Macro OUT_DIR must be defined! Set it in tb_config.cfg.
#endif

#define OUT_DIR_STR STRINGIFY(OUT_DIR/)

#define TOP_TYPE CONCAT2(V, TOP_NAME)
#define TOP_ROOT_TYPE CONCAT3(V, TOP_NAME, ___024root)
#define TOP_SYMS_TYPE CONCAT3(V, TOP_NAME, __Syms)
#define EVAL_SETTLE CONCAT3(V, TOP_NAME, ___024root___eval_settle)
#define EVAL_SETTLE_LOG CONCAT3(V, TOP_NAME, ___024root___eval_settle_log)

#define TOP_SYMS_HEADER STRINGIFY(CONCAT3(V, TOP_NAME, __Syms.h))

#if VM_TRACE_VCD
#include "verilated_vcd_c.h"
#endif
#include TOP_SYMS_HEADER
VL_ATTR_COLD void EVAL_SETTLE(TOP_ROOT_TYPE *vlSelf);
VL_ATTR_COLD void EVAL_SETTLE_LOG(TOP_ROOT_TYPE *vlSelf);
#define XXH_INLINE_ALL
#include "xxhash.h"
#include "resiliator_hash.h"
#include "resiliator_flops.h"
#include "resiliator_log.h"
#include "resiliator_names.h"
#include "resiliator_diff.h"

inline uint64_t hash_state(const std::vector<HashBlock>& blocks)
{
    uint64_t hash = 0;
    for (const HashBlock& block : blocks) {
        hash ^= XXH3_64bits(block.start, block.size);
    }
    return hash;
}

uint64_t unflip_for_hash(FlipFlop& ff, std::vector<HashBlock>& blocks)
{
  ff.flip();
  uint64_t hash = hash_state(blocks);
  ff.flip();
  return hash;
}

#define COL_WIDTH 8

#define SUCCESS_VAL    0xbf4a79cc
#define FAILURE_VAL    0x40b58633
#define CHECKPOINT_VAL 0xd739e749
#define CP_SUCCESS_VAL 0x28c618b6
#define START_INJ_VAL  1
#define END_INJ_VAL    2

#define SIM_RESULTS_FNAME       OUT_DIR_STR "sim_results"
#define DIFF_DUMP_FNAME         OUT_DIR_STR "diff.json"
#define NO_FAULT_VCD_FNAME      OUT_DIR_STR "no_fault.vcd"
#define WITH_FAULT_VCD_FNAME    OUT_DIR_STR "with_fault.vcd"
#define INDICES_TXT_FNAME       OUT_DIR_STR "indices.txt"
#define GOLDEN_HASHES_BIN_FNAME OUT_DIR_STR "golden_hashes.bin"

#define FATAL(...) do { fprintf(stderr, "[FATAL] " __VA_ARGS__); exit(1); } while (0)

// Assumes divisor is a power of 2
#define POW2_ALIGNED_MODULO(val, divisor) ((val) & ((divisor) - 1))

// Shared global variables for logging
int g_cycle_log = 0;
bool g_eval_posedge = true;

// Shared global variables to determine when the injected FF is a sensitivity
bool g_test_if_nba_executed = false;
bool g_nba_executed = false;

// Record hashes after negedge evals, as that is where the injections take place
std::vector<uint64_t> g_golden_hashes_vec;
// Golden hashes don't need extra hashing
struct IdentityHasher {
    size_t operator()(uint64_t key) const {
        return key; 
    }
};
// Record hashes after negedge evals, as that is where the injections take place
std::unordered_set<uint64_t, IdentityHasher> g_golden_hashes_set;

// Injection window
int g_first_cycle = -1;
int g_last_cycle = -1;
// In cycles, when the important cycle range is over + extra buffer
int g_timeout = 0;

// Enables output of differences between golden and faulty run,
// which can be visualized in the browser using streamlit
int g_dump_diff = 0;
std::ofstream g_diff_fd; // file descriptor for the diff

bool g_write_vcd = false;

struct gpio_context_t {
  IData last_value;
};

// Global variables for exhaustive_injections
gpio_context_t g_gpio_context = { 0 };
std::unique_ptr<VerilatedContext> g_contextp_log;
std::unique_ptr<VerilatedContext> g_contextp;
std::unique_ptr<TOP_TYPE> g_top_log;
std::unique_ptr<TOP_TYPE> g_top;
std::vector<HashBlock> g_blocks;
// Pointers to every flip-flop to flip
std::vector<FlipFlop> g_flops;
int g_cycle;
bool g_need_result = false;

bool do_gpio(gpio_context_t *context, IData gpio) {
  if (context->last_value != gpio) {
    context->last_value = gpio;
    return true;
  }
  return false;
}

int hamming_dist(IData n1, IData n2)
{
  IData tmp = n1 ^ n2;
  int res = 0;
  for (; tmp; tmp >>= 1) {
    res += tmp & 1;
  }
  return res;
}

enum class reason_t : uint8_t {
  GOT_FINISH,       // Simulation called $finish
  SUCCESS_REPORTED, // Gpio was set to value of success
  FAILURE_REPORTED, // Gpio was set to value of failure
  FAIL_RAISED,      // Fail signal was raised
  // For DELAYED_*, the simulation was never fully executed due to one of these
  // reasons:
  // 1. Access logging set g_accesses to Access::None for the next cycle.
  // 2. After one cycle, the hash only differed by this FF compared to the
  //    golden hash.
  // The next injection (same FF, next cycle) determined success or failure
  DELAYED_SUCCESS,
  DELAYED_FAILURE,
  OVERWRITTEN,      // Access logging determined that an injected fault would be
                    // overwritten before next read
  RECONVERGED,      // State hash after injection matched a known state from
                    // the golden run
  // For SEEN_BEFORE_*, the state hash one cycle after injection matched a known
  // state hash from a previous injection's simulation
  SEEN_BEFORE_SUCCESS,
  SEEN_BEFORE_FAILURE,
  NO_INFLUENCE,     // State hash one cycle after injection, with the injection
                    // undone, matched the golden state hash of that cycle,
                    // meaning the fault did not spread
  TIMEOUT,          // Simulation got timeout

  COUNT // Count the number of reasons in the enum
};

std::string to_string(reason_t reason)
{
  switch (reason) {
    case reason_t::GOT_FINISH:
        return "Got $finish or $stop";
    case reason_t::SUCCESS_REPORTED:
        return "Success reported";
    case reason_t::FAILURE_REPORTED:
        return "Failure reported";
    case reason_t::FAIL_RAISED:
        return "Fail signal raised";
    case reason_t::DELAYED_SUCCESS:
        return "Same result as next injection (Success)";
    case reason_t::DELAYED_FAILURE:
        return "Same result as next injection (Failure)";
    case reason_t::OVERWRITTEN:
        return "Injection masked (src=logging)";
    case reason_t::RECONVERGED:
        return "Injection masked (src=hash)";
    case reason_t::SEEN_BEFORE_SUCCESS:
        return "State Hash matched known hash (Success)";
    case reason_t::SEEN_BEFORE_FAILURE:
        return "State Hash matched known hash (Failure)";
    case reason_t::NO_INFLUENCE:
        return "Injection had no influence (src=hash)";
    case reason_t::TIMEOUT:
        return "Timeout";
    default:
        FATAL("Called to_string on non-existent reason '%d'\n", static_cast<int>(reason));
  }
  return "";
}

std::string abbreviate(reason_t reason)
{
  switch (reason) {
    case reason_t::GOT_FINISH:
        return "Finish";
    case reason_t::SUCCESS_REPORTED:
        return "RepSucc";
    case reason_t::FAILURE_REPORTED:
        return "RepFail";
    case reason_t::FAIL_RAISED:
        return "SigFail";
    case reason_t::DELAYED_SUCCESS:
        return "EqNextS";
    case reason_t::DELAYED_FAILURE:
        return "EqNextF";
    case reason_t::OVERWRITTEN:
        return "MaskLog";
    case reason_t::RECONVERGED:
        return "MaskHsh";
    case reason_t::SEEN_BEFORE_SUCCESS:
        return "EqHashS";
    case reason_t::SEEN_BEFORE_FAILURE:
        return "EqHashF";
    case reason_t::NO_INFLUENCE:
        return "NoInfl";
    case reason_t::TIMEOUT:
        return "Timeout";
    default:
        FATAL("Called abbreviate on non-existent reason '%d'\n", static_cast<int>(reason));
  }
  return "";
}

struct CampaignStats {
  // Timestamps for the FI campaign
  std::chrono::system_clock::time_point start_time;
  std::chrono::system_clock::time_point end_time;

  uint64_t num_successes = 0;
  uint64_t num_failures = 0;
  uint64_t num_cycles = 0;
  uint64_t num_forks = 0;
  uint64_t num_needed_result = 0;
  uint64_t num_filled_hash_cache_entries = 0;
  uint64_t num_overwritten_hash_cache_entries = 0;
  // Number of times each reason occurred
  std::array<std::array<int, static_cast<size_t>(reason_t::COUNT)>, NUM_FLOPS> num_per_ff_per_reason = {{0}};

  pthread_mutex_t mutex;
};

struct SameResListEntry {
  int cycle;
  int ff;
  int sim_len;
  int num_resp;
};

void report(bool success, int fault_cycle, int fault_ff, int sim_len, int num_resp, reason_t reason);

CampaignStats *g_stats;

// E: Num entries in the block
template<int E>
struct SameResListBlock {
  std::array<SameResListEntry, E> entries;
  SameResListBlock<E> *next;
};

// E: Num entries in each block
template<int E>
struct SameResListControl {
  SameResListBlock<E> *head; // head block
  SameResListBlock<E> *penultimate; // block before tail block
  SameResListBlock<E> *tail; // tail block
  int size; // Size of tail block, others are full
};

// B: Num blocks, E: Num entries per block N: Max num children
template<int B, int E, int N>
class SameResList {
  static_assert(B > 0, "There must be a positive number of blocks!");
  static_assert(E > 0, "There must be a positive number of entries per block!");
  static_assert(N > 0 && N < 254, "The maximum number of children must be "
                "strictly between 0 and 254!");
private:
  std::array<SameResListBlock<E>, B> m_blocks;
  std::array<SameResListControl<E>, N> m_child_lists;
  SameResListBlock<E> *m_freelist_head;

public:
  void init() {
    m_freelist_head = &m_blocks[0];

    for (int i = 0; i < B - 1; ++i) {
      m_blocks[i].next = &m_blocks[i+1];
    }
    m_blocks[B-1].next = nullptr;

    for (SameResListControl<E>& list : m_child_lists) {
      list.head = nullptr;
      list.tail = nullptr;
      list.penultimate = nullptr;
      list.size = 0;
    }
  }

  void insert(int cycle, int ff, int sim_len, int num_resp, uint8_t child_id) {
#ifdef DEBUG
    if (child_id >= N)
      FATAL("Invalid child_id >= N (%d >= %d)\n", child_id, N);
#endif
    auto& list = m_child_lists[child_id];

    // Child's list is empty
    if (!list.head) {
      if (!m_freelist_head) {
        FATAL("Ran out of free blocks!\n");
      }

      SameResListBlock<E> *block = m_freelist_head;

      list.head = block;
      list.tail = block;
      list.penultimate = nullptr;
      list.size = 1; // The one we're going to insert

      m_freelist_head = block->next;

      block->next = nullptr;
      block->entries[0] = {cycle, ff, sim_len, num_resp};
    }
    // Child's list's last block is full, so we need a new one
    else if (list.size == E) {
      if (!m_freelist_head) {
        FATAL("Ran out of free blocks!\n");
      }

      SameResListBlock<E> *block = m_freelist_head;

      list.tail->next = block;
      list.penultimate = list.tail;
      list.tail = block;
      list.size = 1; // The one we're going to insert

      m_freelist_head = block->next;

      block->next = nullptr;
      block->entries[0] = {cycle, ff, sim_len, num_resp};
    }
    // Child's list's last block is not full
    else {
      list.tail->entries[list.size] = {cycle, ff, sim_len, num_resp};
      ++list.size;
    }
  }

  void move(uint8_t src_id, uint8_t dst_id) {
#ifdef DEBUG
    if (src_id == dst_id)
      FATAL("Tried to move a SameResList into itself (src_id=dst_id)\n");
    if (src_id >= N)
      FATAL("Invalid src_id >= N (%d >= %d)\n", src_id, N);
    if (dst_id >= N)
      FATAL("Invalid dst_id >= N (%d >= %d)\n", dst_id, N);
#endif

    SameResListControl<E>& src_list = m_child_lists[src_id];
    SameResListControl<E>& dst_list = m_child_lists[dst_id];

    if (!src_list.head)
      return;

    if (!dst_list.head) {
      dst_list.head = src_list.head;
      dst_list.tail = src_list.tail;
      dst_list.penultimate = src_list.penultimate;
      dst_list.size = src_list.size;
      src_list.head = nullptr;
      src_list.tail = nullptr;
      src_list.penultimate = nullptr;
      src_list.size = 0;
      return;
    }

    SameResListControl<E> *src; // The one with the emptier last block
    SameResListControl<E> *dst; // The one with the fuller last block
    if (src_list.size >= dst_list.size) {
      dst = &src_list;
      src = &dst_list;
    } else {
      src = &src_list;
      dst = &dst_list;
    }

    int dst_leftover = E - dst->size;
    if (src->size > dst_leftover) {
      std::memcpy(&dst->tail->entries[dst->size],
                  &src->tail->entries[src->size - dst_leftover],
                  dst_leftover * sizeof(SameResListEntry));

      dst->tail->next = src->head;

      if (src->penultimate) {
        dst_list.penultimate = src->penultimate;
      } else {
        dst_list.penultimate = dst->tail;
      }
      dst_list.head = dst->head;
      dst_list.tail = src->tail;
      dst_list.size = src->size - dst_leftover;
    } else {
      std::memcpy(&dst->tail->entries[dst->size],
                  &src->tail->entries[0],
                  src->size * sizeof(SameResListEntry));

      // Remove block that was emptied
      src->tail->next = m_freelist_head;
      m_freelist_head = src->tail;

      if (src->penultimate) {
        src->penultimate->next = dst->head;
        dst_list.head = src->head;
        dst_list.penultimate = dst->penultimate ? dst->penultimate : src->penultimate;
      } else {
        dst_list.head = dst->head;
        dst_list.penultimate = dst->penultimate;
      }
      dst_list.tail = dst->tail;
      dst_list.size = src->size + dst->size;
    }

    src_list.head = nullptr;
    src_list.tail = nullptr;
    src_list.penultimate = nullptr;
    src_list.size = 0;
  }

  // Doesn't reset values to zero
  void cleanup(uint8_t child_id, bool success) {
#ifdef DEBUG
    if (child_id >= N)
      FATAL("Invalid child_id >= N (%d >= %d)\n", child_id, N);
#endif
    SameResListControl<E>& list = m_child_lists[child_id];
    reason_t reason = success ? reason_t::SEEN_BEFORE_SUCCESS
                              : reason_t::SEEN_BEFORE_FAILURE;

    SameResListBlock<E> *cur = list.head;

    if (!cur)
      return;

    while (cur) {
      int num_entries = cur->next ? E : list.size;
      for (int i = 0; i < num_entries; ++i) {
        SameResListEntry& entry = cur->entries[i];
        report(success, entry.cycle, entry.ff, entry.sim_len, entry.num_resp, reason);
      }
      cur = cur->next;
    }

    list.tail->next = m_freelist_head;
    m_freelist_head = list.head;

    list.head = nullptr;
    list.tail = nullptr;
    list.penultimate = nullptr;
    list.size = 0;
  }
};

// Result (success or failure) or reference to child id / same result list id
class ResOrRef {
private:
  uint8_t m_datum;

public:
  ResOrRef() : m_datum(0) {} // Default, should not matter
  ResOrRef(uint8_t child_id) : m_datum(child_id) {} // Ref(erence)
  ResOrRef(bool success) { m_datum = success ? 254 : 255; } // Res(ult)

  bool is_ref() const {
    return m_datum < 254;
  }

  uint8_t ref() const {
    return m_datum;
  }

  bool res() const {
    return m_datum == 254;
  }
};

// E: Num entries
template<uint64_t E>
class HashCache {
  static_assert(E > 0 && (E & (E - 1)) == 0, "The number of entries in the "
                "Hash Cache must be positive and a power of 2!");
  static_assert(E >= 2 * HASH_CACHE_BUCKET_ELEMS_LIMIT, 
                "Hash Cache size must be greater than twice the bucket limit!");
private:
  std::array<uint64_t, E> m_hashes;
  std::array<ResOrRef, E> m_res_or_ref;

public:
  std::pair<uint64_t, ResOrRef> at(uint64_t index) {
    return { m_hashes[index], m_res_or_ref[index] };
  }

  // Sets res_or_ref and ret_index if hash exists in the hash cache
  bool exists(uint64_t hash, ResOrRef *res_or_ref, uint64_t *ret_index) {
    uint64_t index = POW2_ALIGNED_MODULO(hash, E);
    // Prevent errors when hash is 0 by replacing it with a value that couldn't
    // be in this bucket naturally. This will prevent collisions.
    if (hash == 0) {
      hash = HASH_CACHE_BUCKET_ELEMS_LIMIT;
    }

    for (int i = 0; i < HASH_CACHE_BUCKET_ELEMS_LIMIT; ++i) {
      uint64_t entry = m_hashes[index];

      if (entry == 0) {
        return false;
      }

      if (entry == hash) {
        *res_or_ref = m_res_or_ref[index];
        *ret_index = index;
        return true;
      }

      index = POW2_ALIGNED_MODULO(index + 1, E);
    }

    return false;
  }

  void insert(uint64_t hash, ResOrRef res_or_ref) {
    uint64_t index = POW2_ALIGNED_MODULO(hash, E);
    // Prevent errors when hash is 0 by replacing it with a value that couldn't
    // be in this bucket naturally. This will prevent collisions.
    if (hash == 0) {
      hash = HASH_CACHE_BUCKET_ELEMS_LIMIT;
    }

    for (int i = 0; i < HASH_CACHE_BUCKET_ELEMS_LIMIT; ++i) {
      if (m_hashes[index] == 0) {
        m_hashes[index] = hash;
        m_res_or_ref[index] = res_or_ref;
        pthread_mutex_lock(&g_stats->mutex);
        ++g_stats->num_filled_hash_cache_entries;
        pthread_mutex_unlock(&g_stats->mutex);
        return;
      }

      if (m_hashes[index] == hash) {
        return;
      }

      index = POW2_ALIGNED_MODULO(index + 1, E);
    }

    // If we get here the cache bucket list is full, so we replace a random one
    // using our hash as the pseudo random number generator (use LSBs that did
    // not contribute to determining the bucket)
    index = POW2_ALIGNED_MODULO(
      index - 1 - POW2_ALIGNED_MODULO(
        hash / E, // Shift out the bucket-determining bits
        HASH_CACHE_BUCKET_ELEMS_LIMIT
      ),
      E
    );

    m_hashes[index] = hash;
    m_res_or_ref[index] = res_or_ref;
    pthread_mutex_lock(&g_stats->mutex);
    ++g_stats->num_overwritten_hash_cache_entries;
    pthread_mutex_unlock(&g_stats->mutex);
  }

  void replace(uint64_t hash, ResOrRef res_or_ref) {
    uint64_t index = POW2_ALIGNED_MODULO(hash, E);
    // Prevent errors when hash is 0 by replacing it with a value that couldn't
    // be in this bucket naturally. This will prevent collisions.
    if (hash == 0) {
      hash = HASH_CACHE_BUCKET_ELEMS_LIMIT;
    }

    for (int i = 0; i < HASH_CACHE_BUCKET_ELEMS_LIMIT; ++i) {
      if (m_hashes[index] == 0) {
        return;
      }

      if (m_hashes[index] == hash) {
        m_res_or_ref[index] = res_or_ref;
        return;
      }

      index = POW2_ALIGNED_MODULO(index + 1, E);
    }
  }

  inline void replace_all(const std::vector<uint64_t>& hashes, ResOrRef res_or_ref) {
    for (uint64_t hash : hashes) {
      replace(hash, res_or_ref);
    }
  }
};

struct InjectionSite {
  int cyc;
  int ff;
};

struct InjectionSiteResult {
  int cyc;
  int ff;
  bool success;
};

// Cycles since up to resp - 1 are unresolved, sim with injection at cycle resp is responsible
struct UnresAccEntry {
  int since;
  int resp;
  UnresAccEntry *next;
};

// N: Max number of children
template<int N>
class UnresolvedAccesses {
private:
  static constexpr int num_entries = NUM_FLOPS + N;

  // Each FF gets their own
  std::array<UnresAccEntry *, NUM_FLOPS> m_heads;
  std::array<UnresAccEntry, num_entries> m_entries;
  UnresAccEntry *m_freelist_head;
  std::array<InjectionSite, N> m_active;
  std::array<InjectionSiteResult, N> m_results;
  int m_num_active;
  int m_num_results;

public:
  void init() {
    for (auto& head : m_heads) {
      head = nullptr;
    }
    for (int i = 0; i < num_entries-1; ++i) {
      m_entries[i].next = &m_entries[i+1];
    }
    m_entries[num_entries-1].next = nullptr;
    m_freelist_head = &m_entries[0];

    m_num_active = 0;
    m_num_results = 0;
  }

  bool store_result_maybe(int fault_cycle, int fault_ff, bool success) {
    for (int i = 0; i < m_num_active; ++i) {
      if (m_active[i].ff == fault_ff && m_active[i].cyc == fault_cycle - 1) {
#ifdef DEBUG
        if (m_num_results >= N)
          FATAL("num_results >= N (=%d)\n", m_num_results);
#endif
        m_results[m_num_results] = {fault_cycle, fault_ff, success};
        ++m_num_results;
        return true;
      }
    }

    return false;
  }

  void remove_result_maybe(int fault_cycle, int fault_ff) {
    for (int i = 0; i < m_num_results; ++i) {
      if (m_results[i].ff == fault_ff && m_results[i].cyc == fault_cycle) {
        --m_num_results;
#ifdef DEBUG
        if (m_num_results < 0)
          FATAL("num_results < 0 (=%d)\n", m_num_results);
#endif
        if (i < m_num_results) {
          m_results[i] = m_results[m_num_results];
        }
        return;
      }
    }
  }

  void free_entry(UnresAccEntry *prev, UnresAccEntry *cur, int ff) {
    if (prev) {
      prev->next = cur->next;
    } else {
      m_heads[ff] = cur->next;
    }
    cur->next = m_freelist_head;
    m_freelist_head = cur;
  }

  // Checks for how many unresolved accesses it is responsible, returns the
  // count and removes these
  int num_responsibilities(int fault_cycle, int fault_ff) {
    UnresAccEntry *cur = m_heads[fault_ff];
    UnresAccEntry *prev = nullptr;

    while (cur) {
      if (cur->resp == fault_cycle) {
        int num_resp = fault_cycle - cur->since;
        free_entry(prev, cur, fault_ff);
        return num_resp;
      }
      prev = cur;
      cur = cur->next;
    }

    return 0;
  }

  void insert(int fault_cycle, int fault_ff) {
    UnresAccEntry *cur = m_heads[fault_ff];
    UnresAccEntry *prev = nullptr;

    while (cur) {
      if (cur->resp == fault_cycle) {
        // Merge if possible
        if (cur->next && cur->next->since == fault_cycle + 1) {
          cur->resp = cur->next->resp;
          free_entry(cur, cur->next, fault_ff);
        } else {
          ++cur->resp;
        }
        return;
      }
      if (cur->since == fault_cycle + 1) {
        cur->since = fault_cycle;
        return;
      }
      if (cur->since > fault_cycle) {
        break;
      }
      prev = cur;
      cur = cur->next;
    }

#ifdef DEBUG
    if (!m_freelist_head)
      FATAL("Ran out of Unresolved Access Entries!\n");
#endif

    UnresAccEntry *new_entry = m_freelist_head;

    m_freelist_head = m_freelist_head->next;

    if (prev) {
      prev->next = new_entry;
    } else {
      m_heads[fault_ff] = new_entry;
    }
    new_entry->next = cur;

    new_entry->since = fault_cycle;
    new_entry->resp = fault_cycle + 1;
  }

  void insert_active(int cycle, int ff) {
#ifdef DEBUG
    if (m_num_active >= N)
      FATAL("num_active >= N (=%d)\n", m_num_active);
#endif
    m_active[m_num_active] = {cycle, ff};
    ++m_num_active;
  }

  void remove_active(int cycle, int ff) {
    for (int i = 0; i < m_num_active; ++i) {
      if (m_active[i].cyc == cycle && m_active[i].ff == ff) {
        --m_num_active;
#ifdef DEBUG
        if (m_num_active < 0)
          FATAL("num_active < 0 (=%d)\n", m_num_active);
#endif
        if (i < m_num_active) {
          m_active[i] = m_active[m_num_active];
        }
        remove_result_maybe(cycle + 1, ff);
        return;
      }
    }
  }

  bool got_result(int fault_cycle, int fault_ff, bool *success) {
    for (int i = 0; i < m_num_results; ++i) {
      if (m_results[i].ff == fault_ff && m_results[i].cyc == fault_cycle) {
        *success = m_results[i].success;
        return true;
      }
    }
    return false;
  }

  uint64_t num_unres() {
    uint64_t total = 0;

    for (UnresAccEntry *cur : m_heads) {
      while (cur) {
        total += cur->resp - cur->since;
        cur = cur->next;
      }
    }

    return total;
  }
};

struct Job {
  int cycle;
  int job; // Repeatedly iterates range [0, NUM_FLOPS-1]
};

// EC: Num entries hash cache, B: Num blocks in same-res-list,
// EL: Num entries per block in same-res-list, N: Max num children
template<uint64_t EC, int B, int EL, int N>
class SharedMemoryBlockTemplated {
private:
  HashCache<EC> m_hash_cache;
  SameResList<B, EL, N> m_same_res_list;
  UnresolvedAccesses<N> m_unres_accesses;
  pthread_rwlock_t m_rwlock; // for m_hash_cache
  pthread_mutex_t m_srl_mutex; // for m_same_res_list
  pthread_mutex_t m_ua_mutex; // for m_unres_accesses
  CampaignStats m_stats;
  Job m_cur_job;
  pthread_mutex_t m_job_mutex; // for m_cur_job

public:
  void init() {
    pthread_rwlockattr_t rwl_attr;
    pthread_rwlockattr_init(&rwl_attr);
    pthread_rwlockattr_setpshared(&rwl_attr, PTHREAD_PROCESS_SHARED);
    pthread_rwlock_init(&m_rwlock, &rwl_attr);

    pthread_mutexattr_t mtx_attr;
    pthread_mutexattr_init(&mtx_attr);
    pthread_mutexattr_setpshared(&mtx_attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&m_srl_mutex, &mtx_attr);

    pthread_mutex_init(&m_ua_mutex, &mtx_attr);
    pthread_mutex_init(&m_stats.mutex, &mtx_attr);
    pthread_mutex_init(&m_job_mutex, &mtx_attr);

    m_same_res_list.init();
    m_unres_accesses.init();

    m_cur_job.cycle = g_first_cycle;
    m_cur_job.job = 0;
  }

  bool does_hash_exist_and_cleanup_if_yes(
              uint64_t hash, int cycle, int ff, int sim_len,
              uint8_t child_id, std::vector<uint64_t>& inserted_hashes) {
    pthread_rwlock_rdlock(&m_rwlock);
    uint64_t index;
    ResOrRef res_or_ref;
    bool exists = m_hash_cache.exists(hash, &res_or_ref, &index);

    if (exists) {
      if (res_or_ref.is_ref()) {
        // If we haven't inserted any hashes, no one depends on us and we can
        // just enlist ourselves, so that the referenced child reports our result
        // for us
        if (inserted_hashes.empty()) {
          pthread_mutex_lock(&m_srl_mutex);
          pthread_rwlock_unlock(&m_rwlock);
          pthread_mutex_lock(&m_ua_mutex);
          int num_resp = m_unres_accesses.num_responsibilities(cycle, ff);
          pthread_mutex_unlock(&m_ua_mutex);
          m_same_res_list.insert(cycle, ff, sim_len, num_resp, res_or_ref.ref());
          pthread_mutex_unlock(&m_srl_mutex);
        } else {
          // Upgrade to write lock
          pthread_rwlock_unlock(&m_rwlock);
          pthread_rwlock_wrlock(&m_rwlock);

          // Check if entry still exists
          std::pair<uint64_t, ResOrRef> entry = m_hash_cache.at(index);

          // If it doesn't exist anymore, we have to keep simulating
          if (entry.first != hash) {
            pthread_rwlock_unlock(&m_rwlock);
            return false;
          }

          res_or_ref = entry.second;

          m_hash_cache.replace_all(inserted_hashes, res_or_ref);

          pthread_mutex_lock(&m_srl_mutex);
          pthread_rwlock_unlock(&m_rwlock);

          // Clean up our m_same_res_list by either moving the list to the new
          // referenced child or reporting the results directly if we have them
          if (res_or_ref.is_ref()) {
            m_same_res_list.move(child_id, res_or_ref.ref());
            pthread_mutex_lock(&m_ua_mutex);
            int num_resp = m_unres_accesses.num_responsibilities(cycle, ff);
            pthread_mutex_unlock(&m_ua_mutex);
            m_same_res_list.insert(cycle, ff, sim_len, num_resp, res_or_ref.ref());
          } else {
            bool success = res_or_ref.res();
            m_same_res_list.cleanup(child_id, success);
            reason_t reason = success ? reason_t::SEEN_BEFORE_SUCCESS : reason_t::SEEN_BEFORE_FAILURE;
            report(success, cycle, ff, sim_len, /* num_resp */ 0, reason);
          }

          pthread_mutex_unlock(&m_srl_mutex);
        }
      } else {
        bool success = res_or_ref.res();

        if (inserted_hashes.empty()) {
          pthread_rwlock_unlock(&m_rwlock);
        } else {
          pthread_rwlock_unlock(&m_rwlock);
          pthread_rwlock_wrlock(&m_rwlock);

          m_hash_cache.replace_all(inserted_hashes, res_or_ref);

          pthread_mutex_lock(&m_srl_mutex);
          pthread_rwlock_unlock(&m_rwlock);
          m_same_res_list.cleanup(child_id, success);
          pthread_mutex_unlock(&m_srl_mutex);
        }

        reason_t reason = success ? reason_t::SEEN_BEFORE_SUCCESS : reason_t::SEEN_BEFORE_FAILURE;
        report(success, cycle, ff, sim_len, /* num_resp */ 0, reason);
      }
    } else {
      pthread_rwlock_unlock(&m_rwlock);
    }

    return exists;
  }

  // Always inserts reference to child_id, never the result (success/failure)
  void hash_insert(uint64_t hash, uint8_t child_id) {
    pthread_rwlock_wrlock(&m_rwlock);
    m_hash_cache.insert(hash, ResOrRef(child_id));
    pthread_rwlock_unlock(&m_rwlock);
  }

  // Replaces all reference to child_ids with the actual results
  // and cleans up the m_same_res_list
  void sim_end_cleanup(bool success, uint8_t child_id, std::vector<uint64_t>& inserted_hashes) {
    pthread_rwlock_wrlock(&m_rwlock);

    m_hash_cache.replace_all(inserted_hashes, ResOrRef(success));

    pthread_mutex_lock(&m_srl_mutex);
    pthread_rwlock_unlock(&m_rwlock);

    m_same_res_list.cleanup(child_id, success);

    pthread_mutex_unlock(&m_srl_mutex);
  }

  // Does handling of unresolved accesses and returns the number of injection
  // sites that are resolved by this result (must be reported by caller)
  int report_result(int cycle, int ff, bool success) {
    pthread_mutex_lock(&m_ua_mutex);
    int num_resp = report_result_logic(cycle, ff, success);
    pthread_mutex_unlock(&m_ua_mutex);

    return num_resp;
  }

  int report_result_logic(int cycle, int ff, bool success) {
    int num_resp;
    if (m_unres_accesses.store_result_maybe(cycle, ff, success)) {
      num_resp = 0;
    } else {
      num_resp = m_unres_accesses.num_responsibilities(cycle, ff);
      if (num_resp != 0) {
        m_unres_accesses.store_result_maybe(cycle - num_resp, ff, success);
      }
    }

    return num_resp;
  }

  // Does handling of unresolved accesses for simulations that reported no
  // influence and returns the number of injection sites that are resolved by
  // this simulation, if its result is already known by the next simulation
  // (this result and the responsibilities must be reported by caller, if known)
  bool report_no_influence(int cycle, int ff, bool *success, int *num_resp) {
    pthread_mutex_lock(&m_ua_mutex);

    if (m_unres_accesses.got_result(cycle + 1, ff, success)) {
      *num_resp = report_result_logic(cycle, ff, *success);
      pthread_mutex_unlock(&m_ua_mutex);
      return true;
    }

    m_unres_accesses.insert(cycle, ff);

    pthread_mutex_unlock(&m_ua_mutex);
    return false;
  }

  void insert_unres_access(int cycle, int ff) {
    pthread_mutex_lock(&m_ua_mutex);
    m_unres_accesses.insert(cycle, ff);
    pthread_mutex_unlock(&m_ua_mutex);
  }

  void insert_active(int cycle, int ff) {
    pthread_mutex_lock(&m_ua_mutex);
    m_unres_accesses.insert_active(cycle, ff);
    pthread_mutex_unlock(&m_ua_mutex);
  }

  void remove_active(int cycle, int ff) {
    pthread_mutex_lock(&m_ua_mutex);
    m_unres_accesses.remove_active(cycle, ff);
    pthread_mutex_unlock(&m_ua_mutex);
  }

  uint64_t num_unres() {
    pthread_mutex_lock(&m_ua_mutex);
    uint64_t result = m_unres_accesses.num_unres();
    pthread_mutex_unlock(&m_ua_mutex);
    return result;
  }

  CampaignStats& stats() {
    return m_stats;
  }

  int job_cycle() {
    pthread_mutex_lock(&m_job_mutex);
    int cycle = m_cur_job.cycle;
    pthread_mutex_unlock(&m_job_mutex);
    return cycle;
  }

  bool next_job_in_cycle(int cycle, int *ff, int step_size) {
    pthread_mutex_lock(&m_job_mutex);

    if (m_cur_job.cycle != cycle) {
      pthread_mutex_unlock(&m_job_mutex);
      return false;
    }

    // step_size is coprime to NUM_FLOPS, so the jobs [0..NUM_FLOPS[ map to the
    // same range, but with a different order
    // (0,step_size,2*step_size,... with wraparound)
    *ff = (m_cur_job.job * step_size) % NUM_FLOPS;

    ++m_cur_job.job;
    if (m_cur_job.job >= NUM_FLOPS) {
      ++m_cur_job.cycle;
      m_cur_job.job = 0;
    }

    insert_active(cycle, *ff);

    pthread_mutex_unlock(&m_job_mutex);

    return true;
  }
};

using SharedMemoryBlock =
  SharedMemoryBlockTemplated<NUM_ENTRIES_HASH_CACHE, NUM_BLOCKS_SAME_RES_LIST,
                             NUM_ENTRIES_SAME_RES_LIST, NPROC>;
SharedMemoryBlock *g_smb;

void report(bool success, int fault_cycle, int fault_ff, int sim_len, int num_resp, reason_t reason)
{
  CampaignStats& stats = g_smb->stats();

  int num_unres = 0;

  // Hashing determined that only this FF was different to the golden hash after one cycle
  if (reason == reason_t::NO_INFLUENCE) {
    bool result_known = g_smb->report_no_influence(fault_cycle, fault_ff,
                                                   &success, &num_unres);
    if (!result_known) {
      pthread_mutex_lock(&stats.mutex);
      stats.num_cycles += static_cast<uint64_t>(sim_len);
      ++stats.num_per_ff_per_reason[fault_ff][static_cast<size_t>(reason)];
      pthread_mutex_unlock(&stats.mutex);
      return;
    }
    // For itself, as NO_INFLUENCE is normally also reported as DELAY_*
    ++num_unres;
  }
  // num_resp is only set for a simulation that was responsible for unresolved
  // accesses, but exited early because its hash was already encountered by
  // another simulation, which wasn't done at that point
  else if (num_resp > 0) {
    num_unres = num_resp;
  } else {
    num_unres = g_smb->report_result(fault_cycle, fault_ff, success);
  }

  if (success) {
    std::string out;
    if (num_unres > 0) {
      if (num_unres == 1) {
        out += "Successful injection at cycle " + std::to_string(fault_cycle - 1);
      } else {
        out += "Successful injections at cycles "
               + std::to_string(fault_cycle - num_unres) + "-"
               + std::to_string(fault_cycle - 1) + " (incl.)";
      }
      out += " at flip-flop " + std::to_string(fault_ff) + " (Reason: "
             + to_string(reason_t::DELAYED_SUCCESS) + ")\n";
    }

    out += "Successful injection at cycle " + std::to_string(fault_cycle)
           + " at flip-flop " + std::to_string(fault_ff) + " after "
           + std::to_string(sim_len) + " more cycles of simulation (Reason: "
           + to_string(reason) + ")\n";

    int fd = open(SIM_RESULTS_FNAME, O_WRONLY | O_APPEND);
    if (fd == -1) {
      fprintf(stderr, "[Warning] While reporting success to flip-flop %d at "
              "cycle %d, open() failed with error %s\n", fault_ff, fault_cycle,
              strerror(errno));
    } else {
      write(fd, out.c_str(), out.length());
      close(fd);
    }
  }

  pthread_mutex_lock(&stats.mutex);
  stats.num_cycles += static_cast<uint64_t>(sim_len);

  if (success) {
    stats.num_successes += 1 + num_unres;
  } else {
    stats.num_failures += 1 + num_unres;
  }

  ++stats.num_per_ff_per_reason[fault_ff][static_cast<size_t>(reason)];

  reason_t unres_reason = success ? reason_t::DELAYED_SUCCESS : reason_t::DELAYED_FAILURE;
  stats.num_per_ff_per_reason[fault_ff][static_cast<size_t>(unres_reason)] += num_unres;

  pthread_mutex_unlock(&stats.mutex);
}

void create_shared_memory_block()
{
  size_t smb_size = sizeof(SharedMemoryBlock); 

  // Create the hash cache shared memory and physically allocate the full map
  // (MAP_POPULATE), so that madvise() can collapse them into huge pages
  // immediately
  g_smb = (SharedMemoryBlock *)mmap(
    nullptr, smb_size, PROT_READ | PROT_WRITE,
    MAP_SHARED | MAP_ANONYMOUS | MAP_POPULATE, -1, 0
  );

  if (g_smb == MAP_FAILED) {
    FATAL("mmap() of size %lu failed!\n", smb_size);
  }

  g_smb->init();

  if (madvise(g_smb, smb_size, MADV_HUGEPAGE) != 0) {
    perror("[Warning] madvise() failed with error");
  }

  g_stats = &g_smb->stats();
}

std::mutex g_print_stats_mutex;

void print_stats(std::ostream& out, bool is_final)
{
  int cur_cycle = g_cycle; // Used only if !is_final
  CampaignStats& stats = g_smb->stats();

  std::chrono::system_clock::time_point cur_time;
  if (is_final) {
    cur_time = stats.end_time;
  } else {
    cur_time = std::chrono::system_clock::now();
  }

  std::time_t start = std::chrono::system_clock::to_time_t(stats.start_time);
  std::time_t cur = std::chrono::system_clock::to_time_t(cur_time);

  struct tm start_tm, cur_tm;
  localtime_r(&start, &start_tm);
  localtime_r(&cur, &cur_tm);

  auto total_seconds = std::chrono::duration_cast<std::chrono::seconds>(cur_time - stats.start_time).count();
  
  long days    = total_seconds / (24 * 3600);
  long hours   = (total_seconds % (24 * 3600)) / 3600;
  long minutes = (total_seconds % 3600) / 60;
  long seconds = total_seconds % 60;

  out << "\nStarted:  " << std::put_time(&start_tm, "%Y-%m-%d %H:%M:%S %Z") << "\n";
  if (is_final) {
    out << "Ended:    " << std::put_time(&cur_tm,   "%Y-%m-%d %H:%M:%S %Z") << "\n"
        << "Duration: " << days << " days, ";
  } else {
    out << "Current:  " << std::put_time(&cur_tm,   "%Y-%m-%d %H:%M:%S %Z") << "\n"
        << "Elapsed:  " << days << " days, ";
  }
  out << std::setfill('0') << std::right
      << std::setw(2) << hours << ":"
      << std::setw(2) << minutes << ":"
      << std::setw(2) << seconds << "\n"
      << std::setfill(' ') << std::left
      << "\n";
  if (!is_final) {
    out << "Current cycle: " << cur_cycle << "\n\n";
  }

  double hash_cache_utilization = (double)stats.num_filled_hash_cache_entries
                                  / NUM_ENTRIES_HASH_CACHE * 100;

  out << "Injection Window : " << g_first_cycle << " - " << g_last_cycle << "\n"
      << "Total Flip-Flops : " << NUM_FLOPS << "\n"
      << "\n"
      << "Total Results    : " << stats.num_successes + stats.num_failures << "\n"
      << "Total Successes  : " << stats.num_successes << "\n"
      << "Total Failures   : " << stats.num_failures << "\n"
      << "Total forks      : " << stats.num_forks << "\n"
      << "Simulated Cycles : " << stats.num_cycles << "\n"
      << "Needed result    : " << stats.num_needed_result << "\n"
      << "Filled HC entries: " << stats.num_filled_hash_cache_entries << " / "
      << NUM_ENTRIES_HASH_CACHE << " (" << std::fixed << std::setprecision(2)
      << hash_cache_utilization << "%)\n"
      << "OverWr HC entries: " << stats.num_overwritten_hash_cache_entries << "\n"
      << "\n"
      << "Number of times a simulation was stopped because of each reason:" << "\n\n";

  std::array<uint64_t, static_cast<size_t>(reason_t::COUNT)> total_per_reason = {0};

  if (is_final) {
    out << "In total:" << "\n";
  }
  for (int i = 0; i < stats.num_per_ff_per_reason.size(); ++i) {
    auto& num_per_reason = stats.num_per_ff_per_reason[i];
    for (int j = 0; j < num_per_reason.size(); ++j) {
      total_per_reason[j] += static_cast<uint64_t>(num_per_reason[j]);
    }
  }
  for (int i = 0; i < total_per_reason.size(); ++i) {
    out << std::setw(COL_WIDTH+2)
        << "(" + abbreviate(static_cast<reason_t>(i)) + ")"
        << std::setw(39)
        << to_string(static_cast<reason_t>(i)) << ": "
        << total_per_reason[i] << "\n";
  }

  if (!is_final) {
    uint64_t num_unres = g_smb->num_unres();
    out << "Same result as next injection (not resolved yet) : "
        << num_unres << "\n";
  }

  out << std::flush;
}

void input_handler()
{
  char c;
  while (true) {
    if (!std::cin.get(c))
      break;

    if (c == '\n')
      continue;

    g_print_stats_mutex.lock();
    if (c == 's') {
      print_stats(std::cout, /* is_final */ false);
    } else {
      std::cout << "Unknown command '" << c << "'" << std::endl;
    }
    g_print_stats_mutex.unlock();

    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
  }
}

void write_diffs_to_file(std::vector<DiffInfo>& diffs, int cycle)
{
  if (!g_diff_fd.is_open()) {
    FATAL("Called write_diffs_to_file, even though g_diff_fd hasn't been opened yet!\n");
  }
  if (cycle > 0) {
    g_diff_fd << ",\n";
  }
  g_diff_fd << "[";

  uint64_t g_val, f_val;
  bool first_iteration = true;
  for (DiffInfo& diff : diffs) {
    if (!first_iteration) {
      g_diff_fd << ",\n";
    } else {
      first_iteration = false;
    }
    g_diff_fd << "{\"name\":\"" << g_names_map[diff.addr_faulty] << "\",";
    switch (diff.size) {
      case 1:
        g_val = *(uint8_t *)diff.addr_golden;
        f_val = *(uint8_t *)diff.addr_faulty;
        break;
      case 2:
        g_val = *(uint16_t *)diff.addr_golden;
        f_val = *(uint16_t *)diff.addr_faulty;
        break;
      case 4:
        g_val = *(uint32_t *)diff.addr_golden;
        f_val = *(uint32_t *)diff.addr_faulty;
        break;
      case 8:
        g_val = *(uint64_t *)diff.addr_golden;
        f_val = *(uint64_t *)diff.addr_faulty;
        break;
      default:
        FATAL("Diff has invalid size %lu\n", diff.size);
    }
    size_t width = diff.size * 2;
    g_diff_fd << "\"golden\":\"0x" << std::setw(width) << g_val << "\","
              << "\"faulty\":\"0x" << std::setw(width) << f_val << "\","
              << "\"diff\":\"0x" << std::setw(width) << (g_val ^ f_val) << "\"}";
  }
  g_diff_fd << "]";
}

void single_sim(int fault_cycle, int fault_ff,
                int first_dump_cycle, int last_dump_cycle,
                int argc, char **argv)
{
  gpio_context_t gpio_context_g = { 0 };
  gpio_context_t gpio_context_f = { 0 };

  // g -> golden, f -> faulty
  const std::unique_ptr<VerilatedContext> contextp_g{new VerilatedContext};
  const std::unique_ptr<VerilatedContext> contextp_f{new VerilatedContext};
  contextp_g->threads(1);
  contextp_f->threads(1);
  contextp_g->commandArgs(argc, argv);
  contextp_f->commandArgs(argc, argv);
  const std::unique_ptr<TOP_TYPE> top_g{new TOP_TYPE{contextp_g.get()}};
  const std::unique_ptr<TOP_TYPE> top_f{new TOP_TYPE{contextp_f.get()}};

  init_names_map(top_f->rootp->vlSymsp);

  // Pointers to every flip-flop to flip
  std::vector<FlipFlop> flops = get_flops(top_f->rootp->vlSymsp);

  top_g->clk = 1;
  top_f->clk = 1;
  int cycle = 0;
  bool done_g = false;
  bool success_g = false;
  bool success_f = false;
  bool hit_checkpoint_g = false;
  bool hit_checkpoint_f = false;

#if VM_TRACE_VCD
  VerilatedVcdC* tfp_g = nullptr;
  VerilatedVcdC* tfp_f = nullptr;
  if (g_write_vcd) {
    Verilated::traceEverOn(true);
    tfp_g = new VerilatedVcdC;
    tfp_f = new VerilatedVcdC;
    top_g->trace(tfp_g, 99);
    top_f->trace(tfp_f, 99);
    tfp_g->open(NO_FAULT_VCD_FNAME);
    tfp_f->open(WITH_FAULT_VCD_FNAME);
  }
#else
  if (g_write_vcd) {
    fprintf(stderr, "Warning: Cannot write VCD file, the model was compiled without --trace\n");
  }
#endif

  // If golden simulation is done, set timeout and continue
  // If faulty simulation is done, stop the simulation
  while (!contextp_f->gotFinish()) {
    if (!g_timeout && contextp_g->gotFinish()) {
      g_timeout = 2 * cycle;
      done_g = true;
    }

    if (!done_g) {
      top_g->rst = (cycle >= START_RESET_CYCLE && cycle < END_RESET_CYCLE)
                || (cycle == END_RESET_CYCLE && top_g->clk);
      top_g->eval();
    }
    top_f->rst = (cycle >= START_RESET_CYCLE && cycle < END_RESET_CYCLE)
              || (cycle == END_RESET_CYCLE && top_f->clk);
    top_f->eval();

    if (top_f->fail && !top_f->rst) {
      break;
    }
    if (!g_timeout && top_g->fail && !top_g->rst) {
      g_timeout = 2 * cycle;
      done_g = true;
    }

    // Inject
    if (!top_f->clk && cycle == fault_cycle) {
      FlipFlop& ff = flops[fault_ff];
      std::cout << "Injecting into " << g_names_map[ff.addr] << ", bit " << +ff.bit_index << std::endl;
      ff.flip();
      // Recompute the combinational logic
      EVAL_SETTLE(top_f->rootp);
      // In case the flipped bit was in a sensitivity list, eval will do something
      top_f->eval();
    }

    if (!done_g && !top_g->clk && g_dump_diff) {
      std::vector<DiffInfo> diffs = state_diff(top_g->rootp->vlSymsp, top_f->rootp->vlSymsp);
      write_diffs_to_file(diffs, cycle);
    }

    if (!done_g && do_gpio(&gpio_context_g, top_g->gpio)) {
      if (hamming_dist(top_g->gpio, SUCCESS_VAL) <= 1) {
        success_g = true;
        done_g = true;
      }

      if (hamming_dist(top_g->gpio, FAILURE_VAL) <= 1) {
        done_g = true;
      }

      if (hamming_dist(top_g->gpio, CHECKPOINT_VAL) <= 1) {
        hit_checkpoint_g = true;
      }

      if (hamming_dist(top_g->gpio, CP_SUCCESS_VAL) <= 1) {
        success_g = hit_checkpoint_g;
        done_g = true;
      }

      if (!g_timeout && done_g) {
        g_timeout = 2 * cycle;
      }
    }

    if (do_gpio(&gpio_context_f, top_f->gpio)) {
      if (hamming_dist(top_f->gpio, SUCCESS_VAL) <= 1) {
        success_f = true;
        break;
      }

      if (hamming_dist(top_f->gpio, FAILURE_VAL) <= 1) {
        break;
      }

      if (hamming_dist(top_f->gpio, CHECKPOINT_VAL) <= 1) {
        hit_checkpoint_f = true;
      }

      if (hamming_dist(top_f->gpio, CP_SUCCESS_VAL) <= 1) {
        success_f = hit_checkpoint_f;
        break;
      }
    }

    if (g_timeout && cycle >= g_timeout) {
      break;
    }

#if VM_TRACE_VCD
    // trace every clock edge to make clk visible
    if (g_write_vcd &&
        (cycle >= (first_dump_cycle == -1 ? fault_cycle : first_dump_cycle)) &&
        (last_dump_cycle == -1 || cycle <= last_dump_cycle)) {
      if (!done_g) {
        tfp_g->dump(cycle*2 + (!top_g->clk));
      }
      tfp_f->dump(cycle*2 + (!top_f->clk));
    }
#endif

    // in case someone uses $dumpfile + $dumpvars in Verilog
    contextp_g->timeInc(1);
    contextp_f->timeInc(1);

    top_g->clk = !top_g->clk;
    top_f->clk = !top_f->clk;
    if (top_f->clk) {
      ++cycle;
    }
  }

#if VM_TRACE_VCD
  if (g_write_vcd) {
    tfp_g->close();
    tfp_f->close();
  }
#endif
  std::cout << (success_f ? "Successful" : "Failed")
            << " injection attack at cycle " << fault_cycle << " at flip-flop "
            << fault_ff << " after " << (cycle - fault_cycle)
            << " more cycles of simulation\n";
  if (success_g) {
    std::cout << "The golden simulation reported success!\n";
  }
}

void golden_sim_with_hashing(int first_dump_cycle, int last_dump_cycle,
                             int argc, char **argv)
{
  gpio_context_t gpio_context = { 0 };

  const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
  contextp->threads(1);
  contextp->commandArgs(argc, argv);
  const std::unique_ptr<TOP_TYPE> top{new TOP_TYPE{contextp.get()}};

  std::vector<HashBlock> blocks = register_hash_blocks(top->rootp->vlSymsp);

  bool done = false;

  top->clk = 1;
  int cycle = 0;
  bool started_injection = false;
  bool ended_injection = false;

#if VM_TRACE_VCD
  VerilatedVcdC* tfp = nullptr;
  if (g_write_vcd) {
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open(NO_FAULT_VCD_FNAME);
  }
#else
  if (g_write_vcd) {
    fprintf(stderr, "Warning: Cannot write VCD file, the model was compiled without --trace\n");
  }
#endif

  while (!(done || contextp->gotFinish())) {
    top->rst = (cycle >= START_RESET_CYCLE && cycle < END_RESET_CYCLE)
            || (cycle == END_RESET_CYCLE && top->clk);
    top->eval();

    if (!top->clk) {
      uint64_t hash = hash_state(blocks);
      g_golden_hashes_vec.push_back(hash);
      g_golden_hashes_set.insert(hash);
    }

    if (do_gpio(&gpio_context, top->gpio) ||
        top->fail ||
        g_first_cycle == cycle ||
        g_last_cycle == cycle) {
      // start injecting
      if (!started_injection &&
          ((g_first_cycle == -1 && top->gpio == START_INJ_VAL) ||
           (g_first_cycle >= 0 && g_first_cycle == cycle))) {
        std::cout << "Start injecting at cycle: " << cycle << std::endl;
        g_first_cycle = cycle;
        started_injection = true;
      }
      // end injecting
      if (!ended_injection && 
          ((g_last_cycle == -1 &&
            (top->gpio == END_INJ_VAL ||
             top->gpio == CHECKPOINT_VAL)) ||
           (g_last_cycle >= 0 && g_last_cycle == cycle))) {
        g_last_cycle = cycle;
        std::cout << "End injecting at cycle (inclusive): " << g_last_cycle << std::endl;
        ended_injection = true;
      }
      // set timeout
      if (top->gpio == SUCCESS_VAL || top->gpio == CP_SUCCESS_VAL
          || top->gpio == FAILURE_VAL || (top->fail && !top->rst)) {
        if (!ended_injection) {
          g_last_cycle = cycle - 1; // no need to inject when failure is already signaled
          std::cout << "End injecting at cycle (inclusive): " << g_last_cycle << std::endl;
        }
        g_timeout = 2 * cycle - g_first_cycle;
        std::cout << "Set timeout at cycle " << cycle << " to " << g_timeout << std::endl;
        if (top->fail)
          std::cout << "Golden simulation stopped because of raised fail signal!" << std::endl;
        if (top->gpio == SUCCESS_VAL)
          std::cout << "Golden simulation stopped because success was signaled!" << std::endl;
        done = true;
      }
    }
    if (contextp->gotFinish()) {
        std::cout << "Golden simulation got finish at cycle " << cycle << std::endl;
    }
    if (g_timeout && cycle >= g_timeout) {
      fprintf(stderr, "Golden simulation got timeout!\n");
      done = true;
    }

#if VM_TRACE_VCD
    // trace every clock edge to make clk visible
    if (g_write_vcd &&
        (first_dump_cycle == -1 ? started_injection : cycle >= first_dump_cycle) &&
        (last_dump_cycle == -1 || cycle <= last_dump_cycle)) {
      tfp->dump(cycle*2 + (!top->clk));
    }
#endif

    // in case someone uses $dumpfile + $dumpvars in Verilog
    contextp->timeInc(1);

    top->clk = !top->clk;
    if (top->clk) {
      ++cycle;
    }
  }
#if VM_TRACE_VCD
  if (g_write_vcd)
    tfp->close();
#endif
}

void child_main(const std::unique_ptr<TOP_TYPE> &top,
                const std::unique_ptr<VerilatedContext> &contextp,
                std::vector<FlipFlop> &flops, int fault_cycle, int fault_ff,
                gpio_context_t &gpio_context, bool need_result,
                std::vector<HashBlock>& blocks,
                uint8_t child_id)
{
  int cycle = fault_cycle;
  bool hit_checkpoint = false;
  bool success = false;
  bool enable_optimization_no_influence = true;
  std::vector<uint64_t> inserted_hashes;

  // immediately inject the fault
  flops[fault_ff].flip();
  // Recompute the combinational logic
  EVAL_SETTLE(top->rootp);
  // In case the flipped bit was in a sensitivity list, eval will do something
  g_test_if_nba_executed = true;
  top->eval();
  if (g_nba_executed) {
    // If the eval actually executed code from the NBA region, then the flipped
    // bit is a sensitivity. In that case, the optimization "No Influence"
    // might yield a matching hash, but the logic that is executed because of
    // the FF's edge might prevent the convergence. If they still converge, the
    // other optimization (SEEN_BEFORE) will catch it.
    enable_optimization_no_influence = false;
    g_nba_executed = false;
  }

  top->clk = !top->clk;
  if (top->clk)
    ++cycle;

  reason_t reason = reason_t::GOT_FINISH;

  while (!contextp->gotFinish()) {
    top->rst = (cycle >= START_RESET_CYCLE && cycle < END_RESET_CYCLE)
            || (cycle == END_RESET_CYCLE && top->clk);
    top->eval();

    if (top->fail && !top->rst) {
      reason = reason_t::FAIL_RAISED;
      break;
    }

    if (!top->clk) {
      if (cycle == fault_cycle + 1) {
        uint64_t hash = hash_state(blocks);

        if (g_golden_hashes_set.find(hash) != g_golden_hashes_set.end()) {
          reason = reason_t::RECONVERGED;
          break;
        }

        if (g_smb->does_hash_exist_and_cleanup_if_yes(
              hash, fault_cycle, fault_ff, cycle - fault_cycle, child_id,
              inserted_hashes)) {
          return;
        }

        if (!need_result && enable_optimization_no_influence &&
            g_golden_hashes_vec[cycle] == unflip_for_hash(flops[fault_ff], blocks)) {
          reason = reason_t::NO_INFLUENCE;
          break;
        }
      }
      else if (cycle == fault_cycle + 2) {
        uint64_t hash = hash_state(blocks);

        if (g_golden_hashes_set.find(hash) != g_golden_hashes_set.end()) {
          reason = reason_t::RECONVERGED;
          break;
        }

        if (g_smb->does_hash_exist_and_cleanup_if_yes(
              hash, fault_cycle, fault_ff, cycle - fault_cycle, child_id,
              inserted_hashes)) {
          return;
        }

        g_smb->hash_insert(hash, child_id);
        inserted_hashes.push_back(hash); 
      }
      else if ((cycle % HASHING_PERIODICITY) == 0) {
        uint64_t hash = hash_state(blocks);

        if (g_golden_hashes_set.find(hash) != g_golden_hashes_set.end()) {
          reason = reason_t::RECONVERGED;
          break;
        }

        if (g_smb->does_hash_exist_and_cleanup_if_yes(
              hash, fault_cycle, fault_ff, cycle - fault_cycle, child_id,
              inserted_hashes)) {
          return;
        }

        g_smb->hash_insert(hash, child_id);
        inserted_hashes.push_back(hash);
      }
    }

    if (do_gpio(&gpio_context, top->gpio)) {
      if (hamming_dist(top->gpio, SUCCESS_VAL) <= 1) {
        success = true;
        reason = reason_t::SUCCESS_REPORTED;
        break;
      }

      if (hamming_dist(top->gpio, FAILURE_VAL) <= 1) {
        reason = reason_t::FAILURE_REPORTED;
        break;
      }

      if (hamming_dist(top->gpio, CHECKPOINT_VAL) <= 1) {
        hit_checkpoint = true;
      }

      if (hamming_dist(top->gpio, CP_SUCCESS_VAL) <= 1) {
        success = hit_checkpoint;
        reason = success ? reason_t::SUCCESS_REPORTED : reason_t::FAILURE_REPORTED;
        break;
      }
    }

    if (cycle >= g_timeout) {
      reason = reason_t::TIMEOUT;
      break;
    }

    top->clk = !top->clk;
    if (top->clk)
      ++cycle;
  }

  g_smb->sim_end_cleanup(success, child_id, inserted_hashes);

  report(success, fault_cycle, fault_ff, cycle - fault_cycle, /* num_resp */ 0, reason);
}

// Assumes g_top->clk is low
void simulate_one_cycle()
{
  // Simulate one cycle and fill the accesses in the logging simulation
  for (int i = 0; i < 2; ++i) {
    g_top_log->rst = (g_cycle_log >= START_RESET_CYCLE
                        && g_cycle_log < END_RESET_CYCLE)
                  || (g_cycle_log == END_RESET_CYCLE && g_top_log->clk);
    if (g_top_log->clk) {
      EVAL_SETTLE_LOG(g_top_log->rootp);
    }
    g_top_log->eval_log();
    g_contextp_log->timeInc(1);
    g_top_log->clk = !g_top_log->clk;
    g_eval_posedge = static_cast<bool>(g_top_log->clk);
  }
  ++g_cycle_log;

  // Simulate one cycle in the (delayed) forking simulation 
  g_contextp->timeInc(1);
  g_top->clk = !g_top->clk; // Transition to high

  // Reset accesses that were just used, as they're not needed anymore;
  std::memset(g_accesses[g_cycle].data(),
              static_cast<int>(Access::None),
              sizeof(g_accesses[g_cycle][0]) * NUM_FLOPS);

  ++g_cycle;

  g_top->rst = (g_cycle >= START_RESET_CYCLE && g_cycle < END_RESET_CYCLE)
            || (g_cycle == END_RESET_CYCLE);
  g_top->eval();

  g_contextp->timeInc(1);
  g_top->clk = !g_top->clk; // Transition to low

  g_top->rst = (g_cycle >= START_RESET_CYCLE && g_cycle < END_RESET_CYCLE);
  g_top->eval();

  g_need_result = g_cycle == g_last_cycle;
}

void forker_proc_func(uint8_t child_id, int step_size)
{
  int ff;
  while (g_smb->next_job_in_cycle(g_cycle, &ff, step_size)) {
    Access acc_next_cyc = g_accesses[g_cycle+1][ff];
    if (acc_next_cyc == Access::Read ||
        (g_need_result && acc_next_cyc == Access::None)) {

      CampaignStats& stats = g_smb->stats();
      pthread_mutex_lock(&stats.mutex);
      ++stats.num_forks;
      if (acc_next_cyc == Access::None) {
        ++stats.num_needed_result;
      }
      pthread_mutex_unlock(&stats.mutex);

      pid_t pid = fork();

      if (pid == 0) {
        child_main(g_top, g_contextp, g_flops, g_cycle, ff, g_gpio_context,
                   g_need_result, g_blocks, child_id);
        _exit(0);
      }

      if (pid == -1) {
        FATAL("fork() returned -1!\n");
      }

      int status;
      int child_pid = waitpid(pid, &status, 0);
      if (child_pid == -1) {
        FATAL("waitpid() returned -1!\n");
      }
      if (status != 0) {
        FATAL("wait() set status to %d!\n", status);
      }
    } else if (acc_next_cyc == Access::Write) {
      report(/* success */ false, g_cycle, ff, /* sim_len */ 0,
             /* num_resp */ 0, reason_t::OVERWRITTEN);
    } else if (acc_next_cyc == Access::None) {
      g_smb->insert_unres_access(g_cycle, ff);
    } else {
      FATAL("Unknown Access type: %d\n", static_cast<int>(acc_next_cyc));
    }

    g_smb->remove_active(g_cycle, ff);
  }
}

void exhaustive_injections(int argc, char **argv)
{
  g_contextp_log.reset(new VerilatedContext);
  g_contextp.reset(new VerilatedContext);
  g_contextp_log->threads(1);
  g_contextp->threads(1);
  g_contextp_log->commandArgs(argc, argv);
  g_contextp->commandArgs(argc, argv);
  g_top_log.reset(new TOP_TYPE{g_contextp_log.get()});
  g_top.reset(new TOP_TYPE{g_contextp.get()});

  // Only need log map for logging simulation
  init_log_map(g_top_log->rootp->vlSymsp);
  // Only need hashes for forking simulation
  g_blocks = register_hash_blocks(g_top->rootp->vlSymsp);

  // Pointers to every flip-flop to flip
  g_flops = get_flops(g_top->rootp->vlSymsp);

  g_top_log->clk = 1;
  g_top->clk = 1;
  g_eval_posedge = true;
  g_cycle_log = 0;
  g_cycle = 0;

  fflush(stdout);

  // Advance both main simulations to the injection window
  while (g_cycle < g_first_cycle) {
    g_top->rst = (g_cycle >= START_RESET_CYCLE && g_cycle < END_RESET_CYCLE)
              || (g_cycle == END_RESET_CYCLE && g_top->clk);
    g_top_log->rst = g_top->rst;

    g_top->eval();
    g_top_log->eval();

    g_contextp->timeInc(1);
    g_contextp_log->timeInc(1);

    g_top->clk = !g_top->clk;
    g_top_log->clk = !g_top_log->clk;

    if (g_top->clk) {
      ++g_cycle;
    }
  }
  g_cycle_log = g_cycle;

  // Do two cycles in logging simulation to establish the offset
  for (int i = 0; i < 4; ++i) {
    g_top_log->rst = (g_cycle_log >= START_RESET_CYCLE && g_cycle_log < END_RESET_CYCLE)
                  || (g_cycle_log == END_RESET_CYCLE && g_top_log->clk);
    if (g_top_log->clk) {
      EVAL_SETTLE_LOG(g_top_log->rootp);
    }
    g_top_log->eval_log();
    g_contextp_log->timeInc(1);
    g_top_log->clk = !g_top_log->clk;
    g_eval_posedge = static_cast<bool>(g_top_log->clk);
    if (g_top_log->clk) {
      ++g_cycle_log;
    }
  }

  g_need_result = g_cycle == g_last_cycle;

  // Simulate to the injection point (after calling eval() on the clock's
  // negative edge) of the current cycle in the (delayed) forking simulation 
  g_top->rst = (g_cycle >= START_RESET_CYCLE && g_cycle < END_RESET_CYCLE)
            || (g_cycle == END_RESET_CYCLE);
  g_top->eval();

  g_contextp->timeInc(1);
  g_top->clk = !g_top->clk; // Transition to low

  g_top->rst = (g_cycle >= START_RESET_CYCLE && g_cycle < END_RESET_CYCLE);
  g_top->eval();

  int step_size = NUM_FLOPS / NPROC;
  if (step_size < 1) {
    step_size = 1;
  }

  auto gcd = [](int a, int b) {
    while (b != 0) {
        int old_b = b;
        b = a % b;
        a = old_b;
    }
    return a;
  };

  // Find a coprime (GCD == 1) that is close to the original step_size
  while (gcd(step_size, NUM_FLOPS) != 1) {
      ++step_size;
  }

  std::array<pid_t, NPROC> pids = {0};

  auto spawn_forker_proc = [&pids](uint8_t child_id, int step_size) {
    CampaignStats& stats = g_smb->stats();
    pthread_mutex_lock(&stats.mutex);
    ++stats.num_forks;
    pthread_mutex_unlock(&stats.mutex);

    g_print_stats_mutex.lock();
    pid_t pid = fork();

    if (pid == 0) {
      // Prevent stdout from being spammed
      fclose(stdout);
      forker_proc_func(child_id, step_size);
      _exit(0);
    }

    g_print_stats_mutex.unlock();

    if (pid == -1) {
      FATAL("fork() returned -1!\n");
    }

    pids[child_id] = pid;
  };

  while (g_cycle <= g_last_cycle) {
    g_need_result = g_cycle == g_last_cycle;

    for (int child_id = 0; child_id < NPROC; ++child_id) {
      if (pids[child_id] == 0) {
        spawn_forker_proc(child_id, step_size);
      }
    }

    while (true) {
      int status;
      pid_t child_pid = wait(&status);
      if (child_pid == -1) {
        FATAL("wait() returned -1!\n");
      }
      if (status != 0) {
        FATAL("wait() set status to %d!\n", status);
      }

      int child_id = -1;
      for (int id = 0; id < NPROC; ++id) {
        if (pids[id] == child_pid) {
          child_id = id;
          break;
        }
      }

      if (child_id == -1)
        FATAL("wait() returned unknown pid %d!", child_pid);

      if (g_smb->job_cycle() <= g_cycle) {
        spawn_forker_proc(child_id, step_size);
      } else {
        pids[child_id] = 0;
        break;
      }
    }

    simulate_one_cycle();
  }

  // Wait for remaining children to finish
  while (true) {
    int status;
    int child_pid = wait(&status);
    if (child_pid == -1) {
      if (errno == ECHILD) {
        break;
      }
      FATAL("wait() returned -1!\n");
    }
    if (status != 0) {
      FATAL("wait() set status to %d!\n", status);
    }
  }
}

void save_hashes_to_file(const char *filename)
{
  std::ofstream golden_hashes_fd(filename, std::ios::out | std::ios::trunc | std::ios::binary);
  if (!golden_hashes_fd.is_open()) {
    FATAL("Failed to open %s to save hashes\n", filename);
  }

  golden_hashes_fd.write(reinterpret_cast<const char *>(&g_first_cycle), sizeof(g_first_cycle));
  golden_hashes_fd.write(reinterpret_cast<const char *>(&g_last_cycle), sizeof(g_last_cycle));
  golden_hashes_fd.write(reinterpret_cast<const char *>(&g_timeout), sizeof(g_timeout));

  golden_hashes_fd.write(
    reinterpret_cast<const char *>(g_golden_hashes_vec.data()),
    g_golden_hashes_vec.size() * sizeof(uint64_t));

  if (!golden_hashes_fd.good()) {
    FATAL("Failed to write hashes to %s\n", filename);
  }
}

void load_hashes_from_file(const char *filename)
{
  std::ifstream golden_hashes_fd(filename, std::ios::in | std::ios::binary);
  if (!golden_hashes_fd.is_open()) {
    FATAL("Failed to open %s to load hashes\n", filename);
  }

  golden_hashes_fd.read(reinterpret_cast<char *>(&g_first_cycle), sizeof(g_first_cycle));
  golden_hashes_fd.read(reinterpret_cast<char *>(&g_last_cycle), sizeof(g_last_cycle));
  golden_hashes_fd.read(reinterpret_cast<char *>(&g_timeout), sizeof(g_timeout));

  if (!golden_hashes_fd.good()) {
    FATAL("Failed to read hashes from %s\n", filename);
  }

  uint64_t hash;
  while (golden_hashes_fd.read(reinterpret_cast<char *>(&hash), sizeof(hash))) {
    g_golden_hashes_vec.push_back(hash);
    g_golden_hashes_set.insert(hash);
  }
}

int get_int(const char *str, char **endptr, bool *error)
{
  long num = strtol(str, endptr, 0);

  if (num > INT_MAX || num < INT_MIN) {
    *error = true;
    return 0;
  }

  *error = false;
  return static_cast<int>(num);
}

// Returns true on error
bool parse_window(char *str, int *first_cycle, int *last_cycle)
{
  if (str[0] == '\0')
    return true;

  char *cur = str;

  // First number
  if (str[0] != '-') {
    bool error;
    *first_cycle = get_int(str, &cur, &error);
    if (error)
      return true;
  }

  if (*cur++ != '-')
    return true;

  // Second number
  if (*cur != '\0') {
    bool error;
    *last_cycle = get_int(cur, nullptr, &error);
    if (error)
      return true;
  }

  return false;
}

int main(int argc, char **argv)
{
  Verilated::commandArgs(argc, argv);

  const char *arg_timeout = Verilated::commandArgsPlusMatch("timeout=");
  if (arg_timeout[0])
    g_timeout = atoi(arg_timeout+9); // "+timeout=" -> 9

  // Default dump cycle is 0 to end of simulation
  int first_dump_cycle = 0;
  int last_dump_cycle = -1;

  int fault_cycle = -1;
  int fault_ff = -1;

  bool save_hashes = false;
  bool load_hashes = false;

  bool error;

  int c;
  opterr = 0;

  while ((c = getopt(argc, argv, "c:f:sldv:w:")) != -1) {
    switch (c) {
      case 'c':
        fault_cycle = get_int(optarg, nullptr, &error);

        if (error) {
          FATAL("Invalid integer used at option -c!\n");
        }

        break;
      case 'f':
        fault_ff = get_int(optarg, nullptr, &error);

        if (error) {
          FATAL("Invalid integer used at option -f!\n");
        }

        if (fault_ff < 0 || fault_ff >= NUM_FLOPS) {
          FATAL("Out of bounds index used at option -f!\n"
                "The allowed range is 0-%d (inclusive).\n", NUM_FLOPS - 1);
        }

        break;
      case 's':
        save_hashes = true;
        break;
      case 'l':
        load_hashes = true;
        break;
      case 'd':
        g_dump_diff = true;
        break;
      case 'v':
        if (optarg[0] == '-' && (optarg[1] < '0' || optarg[1] > '9')) {
          --optind;
        } else {
          error = parse_window(optarg, &first_dump_cycle, &last_dump_cycle);
          if (error) {
            FATAL("Invalid window used at option -v!\n"
                  "Format: <first_cycle>-<last_cycle>.\n"
                  "Leaving the first part empty sets the first cycle of the "
                  "dump window to:\n"
                  "  The cycle of the fault injection if -f and -c specified.\n"
                  "  The first cycle of the injection window if -f and -c are "
                  "not specified.\n"
                  "Leave the second part empty if the simulation should keep "
                  "dumping until it ends.\n");
          }
        }

        g_write_vcd = true;
        break;
      case 'w':
        if (optarg[0] == '-' && (optarg[1] < '0' || optarg[1] > '9')) {
          FATAL("Option -w requires arg specifying the injection window.\n"
                "Format: <first_cycle>-<last_cycle>.\n"
                "Leave one part empty if it should be determined by the "
                "golden simulation.\n");
        }

        error = parse_window(optarg, &g_first_cycle, &g_last_cycle);
        if (error) {
          FATAL("Invalid window used at option -w!\n");
        }

        break;
      case '?':
        if (optopt == 'c') {
          FATAL("Option -c requires arg, at which cycle to inject.\n");
        } else if (optopt == 'f') {
          FATAL("Option -f requires arg, at which flip-flop to inject.\n");
        } else if (optopt == 'w') {
          FATAL("Option -w requires arg specifying the injection window. "
                "Format: <first_cycle>-<last_cycle>. Leave one part empty if "
                "it should be determined by the golden simulation.\n");
        } else if (optopt == 'v') {
          g_write_vcd = true;
          break;
        }

        FATAL("Unknown option `-%c'.\n", optopt);
      default:
        FATAL("Parsing of command-line options failed!\n");
    }
  }

  if ((fault_cycle == -1 && fault_ff != -1) ||
      (fault_cycle != -1 && fault_ff == -1)) {
    FATAL("Options -c and -f must either be used together or not at all!\n");
  }

  if (fault_cycle != -1 && fault_ff != -1) {
    if (g_dump_diff) {
      g_diff_fd.open(DIFF_DUMP_FNAME, std::ios::out | std::ios::trunc);
      if (!g_diff_fd)
        FATAL("Could not open " DIFF_DUMP_FNAME "\n");
      g_diff_fd << std::hex << std::setfill('0') << "[\n";
    }
    // Only allow single bitflips
    single_sim(fault_cycle, fault_ff, first_dump_cycle, last_dump_cycle, argc, argv);
    if (g_dump_diff) {
      g_diff_fd << "]\n";
    }
    return 0;
  }

  int mkdir_ret = mkdir(OUT_DIR_STR, 0777);
  if (mkdir_ret != 0 && errno != EEXIST)
    FATAL("Failed to create output directory " OUT_DIR_STR ", errno=%d\n", errno);

  if (load_hashes) {
    load_hashes_from_file(GOLDEN_HASHES_BIN_FNAME);
  } else {
    golden_sim_with_hashing(first_dump_cycle, last_dump_cycle, argc, argv);
    if (save_hashes) {
      save_hashes_to_file(GOLDEN_HASHES_BIN_FNAME);
    }
  }

  if (g_first_cycle == -1)
    FATAL("Golden simulation did not set g_first_cycle!\n");
  if (g_last_cycle == -1)
    FATAL("Golden simulation did not set g_last_cycle!\n");
  if (!g_timeout)
    FATAL("Golden simulation did not set g_timeout!\n");

  std::cout << "first_cycle/last_cycle/timeout: " << g_first_cycle << "/"
            << g_last_cycle << "/" << g_timeout << std::endl;

  // Clear sim_results file
  {
    std::ofstream results_fd(SIM_RESULTS_FNAME, std::ios::trunc);
  }

  create_shared_memory_block();

  CampaignStats& stats = g_smb->stats();

  std::thread input_handler_thread(input_handler);
  input_handler_thread.detach();

  stats.start_time = std::chrono::system_clock::now();
  exhaustive_injections(argc, argv);
  stats.end_time = std::chrono::system_clock::now();

  std::ofstream results_fd(SIM_RESULTS_FNAME, std::ios::app);

  std::unordered_set<int> ignored_waiting_for;
  print_stats(results_fd, /* is_final */ true);

  results_fd << "\nPer flip-flop:" << "\n";
  // Header row
  results_fd << std::setw(COL_WIDTH) << "FF_ID";
  for (int i = 0; i < static_cast<int>(reason_t::COUNT); ++i) {
    results_fd << std::setw(COL_WIDTH) << abbreviate(static_cast<reason_t>(i));
  }
  results_fd << "\n";

  // Content rows
  results_fd << std::left;
  for (int ff = 0; ff < stats.num_per_ff_per_reason.size(); ++ff) {
    auto& num_per_reason = stats.num_per_ff_per_reason[ff];
    results_fd << std::setw(COL_WIDTH) << ff;
    for (int r = 0; r < num_per_reason.size(); ++r) {
      results_fd << std::setw(COL_WIDTH) << num_per_reason[r];
    }
    results_fd << "\n";
  }

  return 0;
}
