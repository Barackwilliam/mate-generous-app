from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User, normalize_phone


def tokens_for(user):
    refresh = RefreshToken.for_user(user)
    return {"refresh": str(refresh), "access": str(refresh.access_token)}


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "email", "phone", "full_name", "date_joined")
        read_only_fields = ("id", "email", "date_joined")

    def validate_phone(self, value):
        value = normalize_phone(value)
        if value and User.objects.filter(phone=value).exclude(pk=getattr(self.instance, "pk", None)).exists():
            raise serializers.ValidationError("Namba hii ya simu tayari imesajiliwa.")
        return value


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, style={"input_type": "password"})

    class Meta:
        model = User
        fields = ("email", "phone", "full_name", "password")

    def validate_email(self, value):
        value = value.lower()
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Barua pepe hii tayari imesajiliwa.")
        return value

    def validate_phone(self, value):
        value = normalize_phone(value)
        if value and User.objects.filter(phone=value).exists():
            raise serializers.ValidationError("Namba hii ya simu tayari imesajiliwa.")
        return value

    def validate(self, attrs):
        validate_password(attrs["password"], user=User(email=attrs["email"], full_name=attrs["full_name"]))
        return attrs

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class LoginSerializer(serializers.Serializer):
    """Log in with either email or phone number."""

    identifier = serializers.CharField()
    password = serializers.CharField(style={"input_type": "password"})

    def validate(self, attrs):
        identifier = attrs["identifier"].strip()
        email = identifier.lower()
        if "@" not in identifier:
            user = User.objects.filter(phone=normalize_phone(identifier)).first()
            email = user.email if user else None
        user = authenticate(self.context.get("request"), email=email, password=attrs["password"]) if email else None
        if not user:
            raise serializers.ValidationError("Taarifa za kuingia si sahihi.")
        attrs["user"] = user
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField()
    new_password = serializers.CharField()

    def validate_old_password(self, value):
        if not self.context["request"].user.check_password(value):
            raise serializers.ValidationError("Nenosiri la zamani si sahihi.")
        return value

    def validate_new_password(self, value):
        validate_password(value, user=self.context["request"].user)
        return value
