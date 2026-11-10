import re

def mask_mobile(phone: str) -> str:
    """Masks mobile number for privacy (e.g., 9876543210 -> ******3210)."""
    if not phone:
        return "N/A"
    clean = re.sub(r"[^\d]", "", str(phone))
    if len(clean) >= 4:
        return "*" * (len(clean) - 4) + clean[-4:]
    return "****"

def mask_email(email: str) -> str:
    """Masks email address for privacy (e.g., rahul.cs23@gec.edu -> r***@gec.edu)."""
    if not email or "@" not in email:
        return "N/A"
    name_part, domain_part = email.split("@", 1)
    if len(name_part) <= 2:
        masked_name = name_part[0] + "*"
    else:
        masked_name = name_part[0] + "*" * (len(name_part) - 2) + name_part[-1]
    return f"{masked_name}@{domain_part}"

def mask_usn(usn: str) -> str:
    """Masks USN for public displays or logs (e.g., 4GE23CS001 -> 4GE***001)."""
    if not usn or len(usn) < 6:
        return usn or "N/A"
    return usn[:3] + "***" + usn[-3:]
