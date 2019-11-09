﻿/*
    Copyright 2017-2019 Katy Coe - http://www.hearthcode.org - http://www.djkaty.com

    All rights reserved.
*/

using System;
using System.Collections.Generic;
using System.Reflection;

namespace Il2CppInspector.Reflection
{
    public class ParameterInfo
    {
        // IL2CPP-specific data
        public Il2CppParameterDefinition Definition { get; }
        public int Index { get; }

        // Information/flags about the parameter
        public ParameterAttributes Attributes { get; }

        // Custom attributes for this parameter
        public IEnumerable<CustomAttributeData> CustomAttributes => CustomAttributeData.GetCustomAttributes(this);

        // True if the parameter has a default value
        public bool HasDefaultValue => (Attributes & ParameterAttributes.HasDefault) != 0;

        // Default value for the parameter
        public object DefaultValue { get; }

        public bool IsByRef => !ParameterType.ContainsGenericParameters && paramTypeUsage == ParameterType.Definition.byrefTypeIndex;

        public bool IsIn => (Attributes & ParameterAttributes.In) != 0;
        public bool IsOptional => (Attributes & ParameterAttributes.Optional) != 0;
        public bool IsOut => (Attributes & ParameterAttributes.Out) != 0;
        public bool IsRetval => (Attributes & ParameterAttributes.Retval) != 0;

        // The member in which the parameter is defined
        public MemberInfo Member { get; }

        // Name of parameter
        public string Name { get; }

        // Type of this parameter
        private readonly int paramTypeUsage;
        public TypeInfo ParameterType => Member.Assembly.Model.GetTypeFromUsage(paramTypeUsage, MemberTypes.TypeInfo);

        // Zero-indexed position of the parameter in parameter list
        public int Position { get; }

        // Create a parameter. Specify paramIndex == -1 for a return type parameter
        public ParameterInfo(Il2CppInspector pkg, int paramIndex, MethodBase declaringMethod) {
            Index = paramIndex;
            Member = declaringMethod;

            if (paramIndex == -1) {
                Position = -1;
                paramTypeUsage = declaringMethod.Definition.returnType;
                Attributes |= ParameterAttributes.Retval;
                return;
            }

            Definition = pkg.Params[Index];
            Name = pkg.Strings[Definition.nameIndex];
            Position = paramIndex - declaringMethod.Definition.parameterStart;
            paramTypeUsage = Definition.typeIndex;
            var paramType = pkg.TypeUsages[paramTypeUsage];

            if ((paramType.attrs & Il2CppConstants.PARAM_ATTRIBUTE_HAS_DEFAULT) != 0)
                Attributes |= ParameterAttributes.HasDefault;
            if ((paramType.attrs & Il2CppConstants.PARAM_ATTRIBUTE_OPTIONAL) != 0)
                Attributes |= ParameterAttributes.Optional;
            if ((paramType.attrs & Il2CppConstants.PARAM_ATTRIBUTE_IN) != 0)
                Attributes |= ParameterAttributes.In;
            if ((paramType.attrs & Il2CppConstants.PARAM_ATTRIBUTE_OUT) != 0)
                Attributes |= ParameterAttributes.Out;
            if ((paramType.attrs & Il2CppConstants.PARAM_ATTRIBUTE_RESERVED_MASK) != 0)
                Attributes |= ParameterAttributes.ReservedMask;
            if ((paramType.attrs & Il2CppConstants.PARAM_ATTRIBUTE_HAS_FIELD_MARSHAL) != 0)
                Attributes |= ParameterAttributes.HasFieldMarshal;

            if (Position == -1)
                Attributes |= ParameterAttributes.Retval;

            // Default initialization value if present
            if (pkg.ParameterDefaultValue.TryGetValue(paramIndex, out object variant))
                DefaultValue = variant;
        }

        public string GetModifierString() =>
              (IsIn ? "in " : "")
            + (IsByRef? "ref " : "")
            + (IsOut? "out " : "");

        private string getCSharpSignatureString() => $"{GetModifierString()}{ParameterType.CSharpName}";
        public string GetSignatureString() => $"{GetModifierString()}{ParameterType.FullName}";

        public string GetParameterString() => IsRetval? null :
            $"{CustomAttributes.ToString(inline: true).Replace("[ParamArray]", "params")}"
            + $"{getCSharpSignatureString()} {Name}"
            + (HasDefaultValue ? " = " + DefaultValue.ToCSharpValue() : "");

        public string GetReturnParameterString() => !IsRetval? null : getCSharpSignatureString();
    }
}