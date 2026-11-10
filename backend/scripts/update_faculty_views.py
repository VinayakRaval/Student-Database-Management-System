import re

with open("faculty/views.py", "r", encoding="utf-8") as f:
    text = f.read()

# Replace get_queryset
pattern = re.compile(r'    def get_queryset\(self\):.*?return Faculty\.objects\.all\(\)\.select_related\("department", "user"\)', re.DOTALL)

replacement = '''    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        user = request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "HOD":
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if dept and instance.department_id != dept.id:
                raise PermissionDenied("You do not have permission to view faculty from another department.")
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        user_role = (getattr(user, "role", "") or "").upper()
        if user_role == "FACULTY":
            user_role = "PROFESSOR"

        qs = Faculty.objects.all().select_related("department", "user")

        if user_role == "HOD":
            from timetable.views import _resolve_department_for_user
            dept = _resolve_department_for_user(user)
            if not dept:
                return Faculty.objects.none()
            # Enforce HOD department isolation: HOD can ONLY see faculty of their own department
            qs = qs.filter(department=dept)
        else:
            dept_param = self.request.query_params.get("department_id") or self.request.query_params.get("department")
            if dept_param and str(dept_param).lower() != "all":
                if str(dept_param).isdigit():
                    qs = qs.filter(department_id=int(dept_param))
                else:
                    qs = qs.filter(
                        Q(department__name__iexact=dept_param) | Q(department__code__iexact=dept_param)
                    )

        fac_type = self.request.query_params.get("faculty_type") or self.request.query_params.get("employment_type")
        if fac_type:
            fac_type_upper = fac_type.upper()
            if fac_type_upper in ["GUEST", "GUEST_FACULTY"]:
                qs = qs.filter(Q(employment_type="GUEST") | Q(is_guest_faculty=True) | Q(designation__icontains="Guest"))
            elif fac_type_upper in ["PERMANENT", "REGULAR"]:
                qs = qs.filter(Q(employment_type="PERMANENT") & Q(is_guest_faculty=False)).exclude(designation__icontains="Guest")

        search_query = self.request.query_params.get("search")
        if search_query:
            qs = qs.filter(
                Q(name__icontains=search_query) |
                Q(faculty_id__icontains=search_query)
            )

        return qs'''

text, count = pattern.subn(replacement, text, count=1)
assert count == 1, f"Regex match failed: count={count}"

with open("faculty/views.py", "w", encoding="utf-8") as f:
    f.write(text)
print("faculty/views.py get_queryset replaced successfully.")
