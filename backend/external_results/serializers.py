import re
import fitz  # PyMuPDF
from rest_framework import serializers
from .models import ExternalResult, ChangeLog
from rest_framework.response import Response
from rest_framework import status



class ExternalResultSerializer(serializers.ModelSerializer):
    student_name = serializers.CharField(source='student.get_full_name', read_only=True)
    student_email = serializers.EmailField(source='student.email', read_only=True)
    download_url = serializers.SerializerMethodField()

    class Meta:
        model = ExternalResult
        fields = [
            'id', 'student', 'student_name', 'student_email',
            'semester', 'exam_type', 'pdf_file', 'download_url', 'uploaded_at'
        ]
        read_only_fields = ['student', 'uploaded_at', 'student_name', 'student_email', 'download_url']

    def get_download_url(self, obj):
        request = self.context.get('request')
        if obj.pdf_file and request:
            return request.build_absolute_uri(obj.pdf_file.url)
        return None

    # VALIDATE PDF CONTENT
    def validate_pdf_file(self, value):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        instance = getattr(self, 'instance', None)

        # Student or staff editing?
        if user and not user.is_staff:
            target_student = user
        else:
            target_student = instance.student if instance else None

        if not target_student:
            raise serializers.ValidationError("Unable to determine student.")

        student_usn = getattr(target_student, "usn", None)
        if not student_usn:
            raise serializers.ValidationError("Student USN is missing.")

        # Extract PDF text
        try:
            file_bytes = value.read()
            import fitz
            with fitz.open(stream=file_bytes, filetype="pdf") as pdf:
                text = "".join(page.get_text("text") or "" for page in pdf)
        except Exception as e:
            raise serializers.ValidationError(f"Unable to read PDF: {e}")

        # Normalize
        text_upper = text.upper().replace(" ", "")
        normalized_usn = student_usn.upper().replace(" ", "")

        # Check USN
        if normalized_usn not in text_upper:
            value.seek(0)
            raise serializers.ValidationError({
                "pdf_file": [f"PDF does not contain USN {student_usn}"]
            })

        value.seek(0)
        return value

    # GLOBAL VALIDATION
    def validate(self, attrs):
        request = self.context.get("request")
        user = request.user

        # FORCE PDF VALIDATION HERE
        if "pdf_file" in attrs:
            attrs["pdf_file"] = self.validate_pdf_file(attrs["pdf_file"])

        # Determine student
        if user.is_staff:
            student = self.instance.student if self.instance else attrs.get("student")
        else:
            student = user

        # Duplicate check
        qs = ExternalResult.objects.filter(
            student=student,
            semester=attrs.get("semester"),
            exam_type=attrs.get("exam_type")
        )
        if self.instance:
            qs = qs.exclude(id=self.instance.id)

        if qs.exists():
            raise serializers.ValidationError(
                {"detail": "Result for this semester and exam type already exists."}
            )

        return attrs

    def create(self, validated_data):
    # Student upload → enforce student = request.user
     request = self.context.get("request")
     if request and request.user.role != "HOD":
        validated_data["student"] = request.user
     return super().create(validated_data)
