import os
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import inch, cm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    KeepTogether,
    HRFlowable,
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        if self._pageNumber == 1:
            # First page cover decor
            self.saveState()
            self.setFillColor(colors.HexColor("#13246E"))
            self.rect(0, A4[1] - 8, A4[0], 8, fill=1, stroke=0)
            self.setFillColor(colors.HexColor("#0D9488"))
            self.rect(0, 0, A4[0], 8, fill=1, stroke=0)
            self.restoreState()
            return

        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#13246E"))
        # Top Header
        self.drawString(40, A4[1] - 28, "CAMPUSFLOW SDMS — ACCOUNTS ROLE SPECIFICATION & OPERATIONAL MANUAL")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawRightString(A4[0] - 40, A4[1] - 28, "Government Engineering College, Chamarajanagara")

        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.6)
        self.line(40, A4[1] - 33, A4[0] - 40, A4[1] - 33)

        # Bottom Footer
        self.line(40, 36, A4[0] - 40, 36)
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        self.drawString(40, 25, "CONFIDENTIAL & PROPRIETARY — FOR ACCOUNTS & AUDIT STAFF USE ONLY")
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(A4[0] - 40, 25, page_str)
        self.restoreState()


def build_accounts_role_pdf(output_path):
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=36,
        rightMargin=36,
        topMargin=42,
        bottomMargin=46,
    )

    styles = getSampleStyleSheet()

    # Custom Palette
    c_primary = colors.HexColor("#13246E")      # Deep Navy
    c_secondary = colors.HexColor("#1E3A8A")    # Royal Blue
    c_accent = colors.HexColor("#0D9488")       # Teal
    c_amber = colors.HexColor("#D97706")        # Amber
    c_dark = colors.HexColor("#0F172A")         # Slate 900
    c_muted = colors.HexColor("#475569")        # Slate 600
    c_light_bg = colors.HexColor("#F8FAFC")     # Slate 50
    c_border = colors.HexColor("#E2E8F0")       # Border grey

    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=20,
        leading=24,
        textColor=c_primary,
        spaceAfter=4,
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=10.5,
        leading=14,
        textColor=c_secondary,
        spaceAfter=10,
    )

    meta_style = ParagraphStyle(
        'DocMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=c_muted,
    )

    h1_style = ParagraphStyle(
        'Heading1Custom',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=16,
        textColor=c_primary,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True,
    )

    h2_style = ParagraphStyle(
        'Heading2Custom',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=c_secondary,
        spaceBefore=7,
        spaceAfter=3,
        keepWithNext=True,
    )

    body_style = ParagraphStyle(
        'BodyCustom',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=c_dark,
        spaceAfter=4,
    )

    bullet_style = ParagraphStyle(
        'BulletCustom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=c_dark,
        leftIndent=12,
        firstLineIndent=-8,
        spaceAfter=2,
    )

    callout_style = ParagraphStyle(
        'CalloutText',
        parent=styles['Normal'],
        fontName='Helvetica-Oblique',
        fontSize=8,
        leading=11,
        textColor=c_primary,
    )

    table_header_style = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=7.5,
        leading=9.5,
        textColor=colors.white,
        alignment=1,
    )

    table_body_style = ParagraphStyle(
        'TableBody',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7,
        leading=9,
        textColor=c_dark,
    )

    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7,
        leading=8.5,
        textColor=c_primary,
    )

    story = []

    # -------------------------------------------------------------
    # COVER / HEADER BLOCK
    # -------------------------------------------------------------
    header_table_data = [
        [
            Paragraph("<b>GOVERNMENT ENGINEERING COLLEGE, CHAMARAJANAGARA</b><br/><font size='7' color='#64748B'>Department of Technical Education, Government of Karnataka</font>", meta_style),
            Paragraph("<b>CAMPUSFLOW SDMS</b><br/><font size='7' color='#0D9488'>Financial & Accounting System</font>", ParagraphStyle('HRight', parent=meta_style, alignment=2))
        ]
    ]
    t_header = Table(header_table_data, colWidths=[330, 193])
    t_header.setStyle(TableStyle([
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
    ]))
    story.append(t_header)
    story.append(HRFlowable(width="100%", thickness=1.5, color=c_primary, spaceBefore=2, spaceAfter=8))

    story.append(Paragraph("Accounts Role: Complete Specification, Features Matrix & SOP", title_style))
    story.append(Paragraph("Exhaustive Technical Blueprint, 12 Core Functional Modules, State Machines, Data Models & Flowcharts", subtitle_style))

    # Meta card
    meta_box_data = [
        [
            Paragraph("<b>Role ID:</b> ACCOUNTS<br/><b>User Profile:</b> Accounts Officer / Cashier<br/><b>Default Login:</b> accounts@sdms.edu (acc001)", meta_style),
            Paragraph("<b>Authority:</b> DTE Karnataka Norms<br/><b>Approval Head:</b> PRINCIPAL<br/><b>Primary App:</b> <code>fees</code> (SDMS Backend)", meta_style),
            Paragraph("<b>Core Security:</b> IsAccounts Guard + Atomic Txns<br/><b>Audit Trail:</b> Automated Receipt & Reversal Logs<br/><b>Format:</b> DTE Karnataka Bilingual Standard", meta_style),
        ]
    ]
    t_meta = Table(meta_box_data, colWidths=[174, 174, 175])
    t_meta.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), c_light_bg),
        ('BOX', (0,0), (-1,-1), 0.75, c_border),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_meta)
    story.append(Spacer(1, 8))

    # -------------------------------------------------------------
    # SECTION 1: EXECUTIVE SUMMARY
    # -------------------------------------------------------------
    story.append(Paragraph("1. Executive Summary & Role Scope", h1_style))
    story.append(Paragraph(
        "In CampusFlow SDMS, the <b>ACCOUNTS</b> role constitutes the financial directorate of the institution. Operating under the administrative authority of the Principal and complying with Karnataka Department of Technical Education (DTE) statutory regulations, the Accounts Officer governs institutional billing, multi-seat fee structure engineering, counter cashiering, online payment verification, scholarship accounting, controlled reversals, and financial auditing.",
        body_style
    ))
    story.append(Paragraph(
        "The system enforces strict dual control (two-man rule): Accounts designs and proposes fee structures and ingests payments, while the Principal retains executive authority to approve fee structures. Payments cannot be deleted from the database—any correction requires an authorized reversal with mandatory audit reasons, ensuring 100% compliance with government accounting standards.",
        body_style
    ))

    # Callout Box
    callout_data = [[
        Paragraph("<b>Institutional Governance:</b> Fee structures mapped to Department, Academic Year, Semester, and Seat Category automatically provision student fee ledgers across entire cohorts once approved by the Principal. Real-time balance recalculation ensures zero billing discrepancies.", callout_style)
    ]]
    t_callout = Table(callout_data, colWidths=[523])
    t_callout.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#EFF6FF")),
        ('LINELEFT', (0,0), (-1,-1), 3, c_secondary),
        ('BOX', (0,0), (-1,-1), 0.5, colors.HexColor("#BFDBFE")),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_callout)
    story.append(Spacer(1, 8))

    # -------------------------------------------------------------
    # SECTION 2: 12 CORE FUNCTIONAL MODULES
    # -------------------------------------------------------------
    story.append(Paragraph("2. Complete Accounts Features Matrix (12 Modules Analyzed)", h1_style))

    modules_summary = [
        [Paragraph("<b>Module & UI Route</b>", table_header_style), Paragraph("<b>Target Area</b>", table_header_style), Paragraph("<b>Key Functional & Technical Capabilities</b>", table_header_style)],
        [
            Paragraph("<b>1. Accounts Dashboard</b><br/><code>/fees/dashboard</code>", table_body_style),
            Paragraph("Financial Cockpit", table_body_style),
            Paragraph("Live KPIs: Total Collected, Today's Revenue, Total Outstanding, Concessions, Pending Verifications Count & Value. Real-time breakdown charts (by Payment Mode, Seat Type, Department). Live 15-entry transaction ledger with instant receipt modal and inline reversal.", table_body_style)
        ],
        [
            Paragraph("<b>2. Fee Structure Engineering</b><br/><code>/fees/create</code>", table_body_style),
            Paragraph("Curriculum Billing", table_body_style),
            Paragraph("Configure seat-type fee structures (GM, SNQ, Management, Lateral, NRI). Encapsulates 14 authentic Karnataka DTE breakdown components. Live DTE receipt preview recalculates real-time sums during editing.", table_body_style)
        ],
        [
            Paragraph("<b>3. Principal Approval Pipeline</b><br/><code>/fees/detail/:id</code>", table_body_style),
            Paragraph("Governance & Dual Control", table_body_style),
            Paragraph("Accounts submits draft (<code>pending</code>) &rarr; Principal reviews &rarr; Upon approval, system atomically queries matching cohort students and provisions <code>StudentFee</code> ledger records with automated push notifications.", table_body_style)
        ],
        [
            Paragraph("<b>4. Student Fee Ledger</b><br/><code>/fees/students</code>", table_body_style),
            Paragraph("Cohort Directory", table_body_style),
            Paragraph("Multi-filter student fee directory (by USN, Name, Department, Semester, Status). Computes Total Assigned, Net Payable, Total Paid, and Outstanding Balance in real time. Actions: View Statement, Apply Concession, Direct Pay.", table_body_style)
        ],
        [
            Paragraph("<b>5. Counter Payment Recording</b><br/><code>/fees/record-payment</code>", table_body_style),
            Paragraph("Cashiering & Collection", table_body_style),
            Paragraph("In-person fee collection. Auto-fetches unrecorded student dues upon selection. Supports Cash, UPI/QR, Bank Transfer, DD, and Cheque. Component allocation ('ALL' or specific item). Generates official DTE receipt instantly.", table_body_style)
        ],
        [
            Paragraph("<b>6. Payment Verification Queue</b><br/><code>/fees/student-payments</code>", table_body_style),
            Paragraph("Proof Verification", table_body_style),
            Paragraph("Review queue for student-uploaded transaction slips and UPI screenshots. High-resolution document viewer with pan/zoom. Accounts can Verify (issues official DTE receipt) or Reject with mandatory audit remark.", table_body_style)
        ],
        [
            Paragraph("<b>7. Uploaded Proofs Archive</b><br/><code>/fees/uploaded-files</code>", table_body_style),
            Paragraph("Document Repository", table_body_style),
            Paragraph("Centralized visual archive of all student payment counterfoils, challans, and transaction screenshots. Grid & list views, filter by Department, Semester, Academic Year, and Verification Status.", table_body_style)
        ],
        [
            Paragraph("<b>8. Controlled Payment Reversal</b><br/><code>reverse()</code> API", table_body_style),
            Paragraph("Audit & Refund Control", table_body_style),
            Paragraph("Enterprise reversal workflow for bounced cheques or erroneous entries. Requires mandatory justification. Flags record as <code>is_reversed=True</code>, restores student balance atomically, and notifies student.", table_body_style)
        ],
        [
            Paragraph("<b>9. Concessions & Scholarships</b><br/><code>apply-concession</code>", table_body_style),
            Paragraph("Welfare & Fee Waivers", table_body_style),
            Paragraph("Deducts government scholarships (SSP, NSP, EWS, Merit) from gross fees. Tracks approving officer and timestamp. Automatically recalculates balance and updates student payment standing.", table_body_style)
        ],
        [
            Paragraph("<b>10. Official DTE Receipt Engine</b><br/><code>DteFeeReceiptWidget</code>", table_body_style),
            Paragraph("Statutory Compliance", table_body_style),
            Paragraph("Pixel-perfect replication of Karnataka DTE receipt booklet format. Features bilingual title, unique sequential receipt & booklet numbering, 14 standard component items, and automatic Indian currency words converter.", table_body_style)
        ],
        [
            Paragraph("<b>11. Academic Year Completion</b><br/><code>academic-year-summary</code>", table_body_style),
            Paragraph("Annual Standing", table_body_style),
            Paragraph("Annualized financial tracker computing student standing across both odd & even semesters. Renders percentage completion progress bar and status badge (COMPLETED / PARTIALLY_COMPLETED / NOT_COMPLETED).", table_body_style)
        ],
        [
            Paragraph("<b>12. Financial Reports & Exports</b><br/><code>/fees/reports</code>", table_body_style),
            Paragraph("Auditing & Reconciliation", table_body_style),
            Paragraph("4-tab analytical reporting suite: (1) Daily Collections, (2) Defaulters List, (3) Department Breakdown, (4) Concessions Audit. Instant 1-click CSV download for treasury and auditor review.", table_body_style)
        ],
    ]
    t_mod = Table(modules_summary, colWidths=[118, 90, 315])
    t_mod.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_light_bg]),
    ]))
    story.append(t_mod)
    story.append(Spacer(1, 8))

    # Page Break for Deep Dive
    story.append(PageBreak())

    # -------------------------------------------------------------
    # SECTION 3: DEEP DIVE & DTE COMPONENTS
    # -------------------------------------------------------------
    story.append(Paragraph("3. Detailed Module Specifications & Technical Workings", h1_style))

    story.append(Paragraph("The 14 Authentic Karnataka DTE Fee Breakdown Components", h2_style))
    story.append(Paragraph(
        "In compliance with Government of Karnataka Department of Technical Education norms, CampusFlow structures each academic year's fee schedule into 14 distinct statutory heads. When an Accounts Officer creates a fee structure, these components are populated and validated:",
        body_style
    ))

    dte_items = [
        [Paragraph("1. Registration Fee", table_body_style), Paragraph("5. Library Fee", table_body_style), Paragraph("9. ID Card Fee", table_body_style), Paragraph("13. NSS Fee", table_body_style)],
        [Paragraph("2. Tuition Fee", table_body_style), Paragraph("6. Magazine Fee", table_body_style), Paragraph("10. Student Welfare Fee", table_body_style), Paragraph("14. Other / Misc Fee", table_body_style)],
        [Paragraph("3. Sports Fee", table_body_style), Paragraph("7. Library Tax", table_body_style), Paragraph("11. Teacher's Welfare Fee", table_body_style), Paragraph("<b>Total Fee:</b> Sum of items", table_body_style)],
        [Paragraph("4. Union Fee", table_body_style), Paragraph("8. Laboratory Fee", table_body_style), Paragraph("12. Development Fee", table_body_style), Paragraph("<b>Governed By:</b> DTE Karnataka", table_body_style)],
    ]
    t_dte = Table(dte_items, colWidths=[130, 130, 130, 133])
    t_dte.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), c_light_bg),
        ('BOX', (0,0), (-1,-1), 0.75, c_border),
        ('INNERGRID', (0,0), (-1,-1), 0.5, c_border),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_dte)
    story.append(Spacer(1, 6))

    story.append(Paragraph("Dual Payment Channels: Direct Counter Collection vs. Online Student Uploads", h2_style))
    story.append(Paragraph(
        "CampusFlow supports two parallel payment ingestion pathways designed to accommodate both offline counter cashiering and modern digital payments:",
        body_style
    ))
    story.append(Paragraph(
        "&bull; <b>Track A — In-Person Counter Payments (<code>/fees/record-payment</code>):</b> Student visits accounts window. Cashier selects student &rarr; dues auto-load &rarr; enters payment mode (Cash, UPI, Cheque, DD, Bank Transfer) &rarr; system validates uniqueness of reference number &rarr; executes atomic database commit &rarr; immediately generates official DTE receipt &rarr; marks payment <code>verified=True</code>.",
        body_style
    ))
    story.append(Paragraph(
        "&bull; <b>Track B — Student Online Self-Submission (<code>/fee-upload</code>):</b> Student transfers fees via bank or UPI QR code &rarr; uploads screenshot or counterfoil &rarr; payment record created with <code>verified=False</code> &rarr; queued in Accounts Verification Queue &rarr; Accounts inspects document &rarr; Verifies (issues receipt) or Rejects (with mandatory feedback).",
        body_style
    ))

    story.append(Paragraph("Official DTE Bilingual Receipt Engine & Number-to-Words Converter", h2_style))
    story.append(Paragraph(
        "The DTE Receipt widget (<code>dte_fee_receipt_widget.dart</code>) meticulously mirrors the official physical receipt booklet issued across Karnataka government colleges. Key elements include:",
        body_style
    ))
    story.append(Paragraph("&bull; <b>Bilingual Government Banner:</b> Karnataka Government seal, Department of Technical Education, and institution header.", bullet_style))
    story.append(Paragraph("&bull; <b>Unique Numbering:</b> Booklet Series (e.g. <code>10495...</code>) and sequential 7-digit receipt identifier (e.g. <code>0821183</code>).", bullet_style))
    story.append(Paragraph("&bull; <b>Indian Currency Words Algorithm:</b> Custom utility converts numbers into authentic Indian currency prose (e.g. <i>₹32,932 &rarr; 'Thirty Two Thousand Nine Hundred and Thirty Two Rupees Only'</i>).", bullet_style))
    story.append(Paragraph("&bull; <b>Official Signatures & Seals:</b> Pre-configured signature blocks for Cashier and Accounts Officer with print/PDF export readiness.", bullet_style))

    story.append(Paragraph("Cross-Module System Integrations (Corrections, Grievances, Announcements)", h2_style))
    story.append(Paragraph(
        "The ACCOUNTS role is deeply woven into institutional administration across multiple SDMS applications:",
        body_style
    ))
    story.append(Paragraph("&bull; <b>Student Data Corrections (<code>backend/corrections/views.py</code>):</b> Accounts is automatically routed any correction request under the <code>FEES</code> category (e.g., student quota updates or fee category revisions).", bullet_style))
    story.append(Paragraph("&bull; <b>Grievance Redressal (<code>backend/grievances/views.py</code>):</b> Fee-related grievances submitted by students or parents are dynamically assigned to the Accounts Officer for investigation and response.", bullet_style))
    story.append(Paragraph("&bull; <b>Principal Directives & Announcements (<code>backend/announcements/</code>):</b> Accounts receives real-time official directives, executive budget orders, and fee structure approval notifications directly in the notifications hub.", bullet_style))
    story.append(Paragraph("&bull; <b>Library Fine Integration (<code>backend/library/signals.py</code>):</b> Overdue book fines recorded by the librarian trigger automated signals notifying Accounts of pending student dues.", bullet_style))

    # Page Break for Flowcharts & Schema
    story.append(PageBreak())

    # -------------------------------------------------------------
    # SECTION 4: FLOWCHARTS & PROCESS STATE MACHINES
    # -------------------------------------------------------------
    story.append(Paragraph("4. System Flowcharts & Process State Machines", h1_style))
    story.append(Paragraph("The visual architectures below outline the life cycles of fee structures, payment verification, and ledger reconciliation.", body_style))

    story.append(Paragraph("Flowchart 1: End-to-End Institutional Fee Lifecycle", h2_style))

    flow_table_data = [
        [Paragraph("<b>Step / Actor</b>", table_header_style), Paragraph("<b>Operational Process Flow</b>", table_header_style), Paragraph("<b>Database & State Transition</b>", table_header_style)],
        [
            Paragraph("<b>1. Accounts Officer</b>", table_body_style),
            Paragraph("Drafts fee structure for Dept, Sem, Academic Year & Seat Category. Adds 14 DTE components. Submits for review.", table_body_style),
            Paragraph("<code>FeeStructure(approval_status='pending', is_active=False)</code>.<br/>Notification sent to Principal.", code_style)
        ],
        [
            Paragraph("<b>2. Principal</b>", table_body_style),
            Paragraph("Reviews total fee, component breakdown, and regulatory compliance. Approves or Rejects with remark.", table_body_style),
            Paragraph("If Approved: <code>approval_status='approved', is_active=True</code>.<br/>If Rejected: <code>rejection_remark='...'</code>.", code_style)
        ],
        [
            Paragraph("<b>3. Automated Engine</b>", table_body_style),
            Paragraph("System queries active students matching Dept, Sem, Academic Year, and Seat Type. Provisions student ledgers.", table_body_style),
            Paragraph("Bulk creates <code>StudentFee</code> records. Net payable computed. Dispatches push notification to students.", code_style)
        ],
        [
            Paragraph("<b>4. Ingestion Channel</b>", table_body_style),
            Paragraph("<b>Path A (Counter):</b> Cashier enters payment directly.<br/><b>Path B (Online):</b> Student pays and uploads slip.", table_body_style),
            Paragraph("Path A: <code>FeePayment(verified=True)</code>.<br/>Path B: <code>FeePayment(verified=False)</code>.", code_style)
        ],
        [
            Paragraph("<b>5. Verification & Receipt</b>", table_body_style),
            Paragraph("Accounts verifies Path B proof or completes Path A cashiering. System issues official DTE receipt.", table_body_style),
            Paragraph("Generates <code>FeeReceipt</code> record.<br/>Updates <code>StudentFee.status</code> &rarr; 'partial' or 'paid'.", code_style)
        ],
        [
            Paragraph("<b>6. Audit & Reporting</b>", table_body_style),
            Paragraph("Accounts monitors daily collections, exports defaulter reports, and reconciles treasury accounts.", table_body_style),
            Paragraph("Data exported via <code>FeeReportsView</code> as downloadable CSV spreadsheets.", code_style)
        ],
    ]
    t_flow = Table(flow_table_data, colWidths=[95, 238, 190])
    t_flow.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_light_bg]),
    ]))
    story.append(t_flow)
    story.append(Spacer(1, 6))

    story.append(Paragraph("Flowchart 2: Payment Verification & Reversal State Machine", h2_style))

    state_machine_box = [
        [
            Paragraph("""<b>State Progression:</b><br/>
[Student Uploads Proof Slip] &rarr; <b>PENDING VERIFICATION</b> (verified=False, is_reversed=False)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&boxur;&rarr; <b>Accounts Action: REJECT</b> &rarr; <b>REJECTED</b> (Remark recorded, student notified to re-upload)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&boxdr;&rarr; <b>Accounts Action: VERIFY</b> &rarr; <b>VERIFIED & ACTIVE</b> (verified=True, Official DTE Receipt generated)<br/>
<br/>
[Counter Direct Cashiering] &rarr; <b>VERIFIED & ACTIVE</b> (verified=True, DTE Receipt issued immediately)<br/>
&nbsp;&nbsp;&nbsp;&nbsp;&boxur;&rarr; <b>Authorized Action: REVERSE</b> &rarr; <b>REVERSED</b> (Reason logged, balance restored, receipt invalidated)
""", code_style)
        ]
    ]
    t_sm = Table(state_machine_box, colWidths=[523])
    t_sm.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#F1F5F9")),
        ('BOX', (0,0), (-1,-1), 0.75, c_secondary),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(t_sm)
    story.append(Spacer(1, 8))

    # -------------------------------------------------------------
    # SECTION 5: DATABASE SCHEMA & MODELS ARCHITECTURE
    # -------------------------------------------------------------
    story.append(Paragraph("5. Database Schema & Architecture (fees App)", h1_style))
    story.append(Paragraph("The backend architecture in <code>backend/fees/models.py</code> comprises 5 core normalized relational models:", body_style))

    schema_data = [
        [Paragraph("<b>Model Name</b>", table_header_style), Paragraph("<b>Key Attributes & Data Fields</b>", table_header_style), Paragraph("<b>Constraints & Technical Logic</b>", table_header_style)],
        [
            Paragraph("<b>FeeStructure</b><br/><code>fee_structure</code>", table_body_style),
            Paragraph("department, academic_year, semester, seat_type, title, description, is_active, approval_status, approved_by, approved_on, created_by, rejection_remark", table_body_style),
            Paragraph("Unique on (dept, academic_year, sem, seat_type, title). Total calculated as dynamic sum of child components.", table_body_style)
        ],
        [
            Paragraph("<b>FeeComponent</b><br/><code>fee_component</code>", table_body_style),
            Paragraph("fee_structure (FK), name (max 80 chars), amount (decimal 12,2)", table_body_style),
            Paragraph("Cascade delete with parent structure. Unique constraint on (fee_structure, name).", table_body_style)
        ],
        [
            Paragraph("<b>StudentFee</b><br/><code>student_fee</code>", table_body_style),
            Paragraph("student (FK), fee_structure (FK), due_date, status (pending/partial/paid), concession_amount, concession_reason, concession_approved_by, concession_approved_on", table_body_style),
            Paragraph("Unique on (student, fee_structure). Balance = (Total - Concession) - Paid. Auto-calculates status on payment/reversal.", table_body_style)
        ],
        [
            Paragraph("<b>FeePayment</b><br/><code>fee_payment</code>", table_body_style),
            Paragraph("student_fee (FK), amount, mode (cash/upi/bank/dd/cheque/online), paid_on, reference_no, upi_txn_id, upi_screenshot, bank_reference_no, bank_statement_file, entered_by, verified, remark, is_reversed, reversed_at, reversed_by, reversal_reason", table_body_style),
            Paragraph("Clean method enforces duplicate reference checks across active payments. Reversal tracks actor and reason without hard deletion.", table_body_style)
        ],
        [
            Paragraph("<b>FeeReceipt</b><br/><code>fee_receipt</code>", table_body_style),
            Paragraph("payment (OneToOne), receipt_no, issued_on, verified_by", table_body_style),
            Paragraph("Receipt numbers formatted via <code>REC-YYYYMMDDHHMMSSffffff</code> or sequential counter. Protected on delete.", table_body_style)
        ],
    ]
    t_sch = Table(schema_data, colWidths=[95, 238, 190])
    t_sch.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_primary),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('TOPPADDING', (0,0), (-1,-1), 3),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_light_bg]),
    ]))
    story.append(t_sch)

    # Page Break for SOP & Security
    story.append(PageBreak())

    # -------------------------------------------------------------
    # SECTION 6: STANDARD OPERATING PROCEDURES (SOP)
    # -------------------------------------------------------------
    story.append(Paragraph("6. Standard Operating Procedures (Accounts Staff SOP)", h1_style))

    story.append(Paragraph("SOP 1: Creating and Submitting a New Fee Structure", h2_style))
    story.append(Paragraph("1. Log in with Accounts credentials (<code>accounts@sdms.edu</code>) and navigate to <b>Fee Structure &rarr; Create Structure</b> (<code>/fees/create</code>).", bullet_style))
    story.append(Paragraph("2. Select Department (e.g. CSE), Academic Year (2025-2026), Semester (Sem 3), and Seat Quota (General Merit).", bullet_style))
    story.append(Paragraph("3. Enter an official title (e.g. <i>'B.E. CSE 3rd Sem GM Fee Structure'</i>).", bullet_style))
    story.append(Paragraph("4. Populate the 14 standard DTE fee components. The live DTE receipt preview dynamically computes the gross fee.", bullet_style))
    story.append(Paragraph("5. Click <b>Submit for Principal Approval</b>. The structure is saved as 'Pending Principal Approval'. The Principal receives an instant directive notification.", bullet_style))

    story.append(Paragraph("SOP 2: Direct Counter Payment Recording (Cashier Window)", h2_style))
    story.append(Paragraph("1. Navigate to <b>Record Payment</b> (<code>/fees/record-payment</code>).", bullet_style))
    story.append(Paragraph("2. In the Search Student bar, enter the student's USN or name. Click to select.", bullet_style))
    story.append(Paragraph("3. The system automatically populates the student profile, fee breakdown, remaining balance, and the Academic Year Completion card.", bullet_style))
    story.append(Paragraph("4. Select Payment Mode (Cash, UPI, Bank Transfer, DD, Cheque). If UPI or Bank, enter the transaction/reference number.", bullet_style))
    story.append(Paragraph("5. If paying for a specific fee head (e.g. Tuition Fee only), pick that component; otherwise leave as 'ALL'.", bullet_style))
    story.append(Paragraph("6. Click <b>Record Payment & Generate Official Receipt</b>. The official DTE receipt dialog appears with instant print and PDF options.", bullet_style))

    story.append(Paragraph("SOP 3: Verifying or Rejecting Student Online Payment Uploads", h2_style))
    story.append(Paragraph("1. Navigate to <b>Verify Payments</b> (<code>/fees/student-payments</code>).", bullet_style))
    story.append(Paragraph("2. Filter by status 'Pending'. Inspect the student USN, claimed amount, and click the document thumbnail to launch the high-res proof viewer.", bullet_style))
    story.append(Paragraph("3. Cross-reference the transaction ID against institutional bank credit advice. If valid, click <b>Verify & Issue Receipt</b>. If invalid or blurred, click <b>Reject</b> and supply a detailed reason.", bullet_style))

    story.append(Paragraph("SOP 4: Executing an Authorized Payment Reversal", h2_style))
    story.append(Paragraph("1. From the <b>Accounts Dashboard</b> (<code>/fees/dashboard</code>), locate the transaction under <b>Recent Transactions</b>.", bullet_style))
    story.append(Paragraph("2. Click the red <b>Reverse</b> button.", bullet_style))
    story.append(Paragraph("3. Provide an authorized justification (e.g. <i>'Cheque #402910 bounced due to insufficient funds'</i>).", bullet_style))
    story.append(Paragraph("4. Confirm reversal. The payment status changes to REVERSED, the student's balance is automatically restored, and an audit notification is dispatched.", bullet_style))

    story.append(Paragraph("SOP 5: Applying Fee Concessions & Government Scholarships", h2_style))
    story.append(Paragraph("1. Open <b>Student Fees</b> (<code>/fees/students</code>) and locate the student by USN.", bullet_style))
    story.append(Paragraph("2. Click the <b>Apply Concession</b> action icon.", bullet_style))
    story.append(Paragraph("3. Enter the concession amount (must not exceed gross fee) and the scholarship scheme name (e.g. <i>'SSP Post-Matric Scholarship'</i> or <i>'Sports Merit Concession'</i>).", bullet_style))
    story.append(Paragraph("4. Click Save. The net payable balance recalculates immediately and updates student records across all portals.", bullet_style))

    story.append(Paragraph("SOP 6: Generating & Exporting Financial Reports", h2_style))
    story.append(Paragraph("1. Open <b>Financial Reports</b> (<code>/fees/reports</code>).", bullet_style))
    story.append(Paragraph("2. Select desired tab: <b>Daily Collections</b>, <b>Defaulters List</b>, <b>Department Summary</b>, or <b>Concessions</b>.", bullet_style))
    story.append(Paragraph("3. Review analytics or click <b>Export CSV</b> to download the formatted audit spreadsheet.", bullet_style))

    story.append(Spacer(1, 6))

    # -------------------------------------------------------------
    # SECTION 7: SECURITY & AUDIT CONTROLS
    # -------------------------------------------------------------
    story.append(Paragraph("7. Security, Compliance & Audit Controls", h1_style))
    story.append(Paragraph("&bull; <b>Role-Based Access Control (RBAC):</b> Direct payment recording, manual verification, and reversal are protected by the <code>IsAccounts</code> permission class. Unauthorized roles receive strict 403 Forbidden responses.", bullet_style))
    story.append(Paragraph("&bull; <b>Atomic Database Transactions (<code>@transaction.atomic</code>):</b> Payment creation, receipt numbering, status recalculation, and notification dispatch are executed inside atomic blocks. If any step fails, the entire transaction rolls back cleanly.", bullet_style))
    story.append(Paragraph("&bull; <b>Anti-Duplicate Safeguards:</b> All transaction references are cross-checked across the database to prevent duplicate payment claims.", bullet_style))
    story.append(Paragraph("&bull; <b>Immutability of Financial History:</b> Payment records are never hard-deleted; reversals maintain a full audit trail including timestamp and approving user identity.", bullet_style))

    story.append(Spacer(1, 10))
    story.append(HRFlowable(width="100%", thickness=1, color=c_primary, spaceBefore=4, spaceAfter=6))
    story.append(Paragraph("<b>End of Specification Document</b> &mdash; CampusFlow SDMS Accounts Role & Financial Directorate", ParagraphStyle('EndDoc', parent=meta_style, alignment=1)))

    # Build document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated PDF: {output_path}")

if __name__ == '__main__':
    target_path = sys.argv[1] if len(sys.argv) > 1 else 'CampusFlow_Accounts_Role_Comprehensive_Guide.pdf'
    build_accounts_role_pdf(target_path)
