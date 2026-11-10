with open("faculty/serializers.py", "r", encoding="utf-8") as f:
    text = f.read()

target1 = '''            "role",
            "employment_type",'''

rep1 = '''            "role",
            "designation",
            "employment_type",'''

if target1 in text:
    text = text.replace(target1, rep1, 1)

target2 = '''            if caller_role == 'HOD':
                if value and value.upper() in ['PRINCIPAL', 'SYSTEM']:
                    raise serializers.ValidationError("HOD is not authorized to assign Principal or System Admin roles.")'''

rep2 = '''            if caller_role == 'HOD':
                allowed = ['PROFESSOR', 'GUEST_FACULTY', 'GUEST', 'FACULTY']
                if value and value.upper() not in allowed:
                    raise serializers.ValidationError("HOD can only assign Professor or Guest Faculty designations.")'''

if target2 in text:
    text = text.replace(target2, rep2, 1)

with open("faculty/serializers.py", "w", encoding="utf-8") as f:
    f.write(text)
print("faculty/serializers.py updated.")
