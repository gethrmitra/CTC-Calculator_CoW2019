// ============================================================
// Wage Code CTC calculation logic
// All rates come from formula_config / mw_rates in Supabase —
// nothing here is hardcoded, so admin edits take effect live.
// ============================================================

/**
 * Solve monthly Basic given fixed monthly HRA + Other Excluded
 * Allowance inputs, the state minimum wage, and the config rates.
 *
 * Definitions used (as specified):
 *   Remuneration (R) = Basic + HRA + Other Excluded Allowance
 *                       + Employer PF + Statutory Bonus
 *   Basic            = max( basic_pct * R , Minimum Wage )
 *   Statutory Bonus  = bonus_pct * Basic, ONLY if Basic < bonus ceiling
 *   Employer PF      = epf_employer_pct * Basic
 *
 * Because R depends on Basic and Basic depends on R, this is solved
 * with a few iterations (converges in 2–3 passes for these linear
 * rates) rather than a brittle closed-form formula.
 */
function solveBasic({ hra, otherAllowance, minWage, cfg }) {
  const basicPct = cfg.basic_pct_of_remuneration;
  const epfEmployerPct = cfg.epf_employer_pct;
  const bonusPct = cfg.bonus_pct;
  const bonusCeiling = cfg.bonus_wage_ceiling_monthly;

  let basic = Math.max(minWage, hra + otherAllowance); // seed guess

  for (let i = 0; i < 25; i++) {
    const statutoryBonus = basic < bonusCeiling ? bonusPct * basic : 0;
    const employerPF = epfEmployerPct * basic;
    const remuneration =
      basic + hra + otherAllowance + employerPF + statutoryBonus;
    const nextBasic = Math.max(basicPct * remuneration, minWage);
    if (Math.abs(nextBasic - basic) < 0.01) {
      basic = nextBasic;
      break;
    }
    basic = nextBasic;
  }
  return basic;
}

/**
 * Full breakdown given monthly HRA + Other Excluded Allowance inputs,
 * state minimum wage, and config rates. Returns all monthly figures.
 */
function computeStructure({ hra, otherAllowance, minWage, cfg }) {
  const basic = solveBasic({ hra, otherAllowance, minWage, cfg });

  const statutoryBonus =
    basic < cfg.bonus_wage_ceiling_monthly ? cfg.bonus_pct * basic : 0;
  const employerPF = cfg.epf_employer_pct * basic;
  const employeePF = cfg.epf_employee_pct * basic;

  const remuneration = basic + hra + otherAllowance + employerPF + statutoryBonus;

  const grossForESIC = basic + hra + otherAllowance; // gross cash wages
  const esicApplicable = grossForESIC <= cfg.esic_wage_ceiling_monthly;
  const employerESIC = esicApplicable ? cfg.esic_employer_pct * grossForESIC : 0;
  const employeeESIC = esicApplicable ? cfg.esic_employee_pct * grossForESIC : 0;

  const gratuity = cfg.gratuity_pct * basic;

  const ctc = remuneration + employerESIC + gratuity;

  const cih = basic + hra + otherAllowance - employeePF - employeeESIC;

  return {
    basic,
    hra,
    otherAllowance,
    employerPF,
    employeePF,
    statutoryBonus,
    bonusApplicable: basic < cfg.bonus_wage_ceiling_monthly,
    employerESIC,
    employeeESIC,
    esicApplicable,
    gratuity,
    remuneration,
    ctc,
    cih,
    minWage,
    basicBelowMinWage_flagged: basic <= minWage + 0.01,
  };
}
