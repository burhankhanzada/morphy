import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

////import 'package:analyzer_models/analyzer_models.dart';
import 'package:build/src/build_step.dart';
import 'package:dartx/dartx.dart';
import 'package:morphy/src/common/GeneratorForAnnotationX.dart';
import 'package:morphy/src/common/NameType.dart';
import 'package:morphy/src/common/classes.dart';
import 'package:morphy/src/common/helpers.dart';
import 'package:morphy/src/common/trees.dart';
import 'package:morphy/src/createMorphy.dart';
import 'package:morphy/src/helpers.dart';
import 'package:morphy_annotation/morphy_annotation.dart';
import 'package:source_gen/source_gen.dart';

//List<NameTypeClassComment> getAllFields(List<InterfaceType> interfaceTypes, ClassElement element) {
//  var superTypeFields = interfaceTypes //
//      .where((x) => x.element.name != "Object")
//      .flatMap((st) => st.element.fields.map((f) => //
//          NameTypeClassComment(f.name, f.type.toString(), st.element.name, comment: f.getter.documentationComment)))
//      .toList();
//  var classFields = element.fields.map((f) => //
//      NameTypeClassComment(f.name, f.type.toString(), element.name, comment: f.getter.documentationComment)).toList();
//
//  //distinct, will keep classFields over superTypeFields
//  return (classFields + superTypeFields).distinctBy((x) => x.name).toList();
//}

class MorphyGenerator<TValueT extends MorphyX>
    extends GeneratorForAnnotationX<TValueT> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    Element ce,
    ConstantReader annotation,
    BuildStep buildStep,
    List<ClassElement> allClasses,
  ) {
    var sb = StringBuffer();

    //    sb.writeln("//RULES: you must use implements, not extends");

    if (ce is! ClassElement) {
      throw Exception("not a class");
    }

    var hasConstConstructor = ce.constructors.any((e) => e.isConst);

    if (ce.supertype?.element.name != "Object") {
      throw Exception("you must use implements, not extends");
    }

    var docComment = ce.documentationComment;

    var isAbstract = ce.name!.startsWith("\$\$");
    var allFields = getAllFields(
      ce.allSupertypes,
      ce,
    ).where((x) => x.name != "hashCode").toList();

    var className = ce.name!;
    var interfaces = ce.interfaces
        .map(
          (e) => //
          InterfaceWithComment(
            e.element.name!, //
            e.typeArguments.map((e) => e.toString()).toList(),
            e.element.typeParameters.map((x) => x.name!).toList(),
            e.element.fields
                .map((e) => NameType(e.name!, e.type.toString()))
                .toList(),
            comment: e.element.documentationComment,
          ),
        ) //
        .toList();

    //    interfaces.forEach((element) {
    //      sb.writeln("//interfacefields: ${element.fields.toString()})");
    //    });

    var classGenerics = ce.typeParameters
        .map(
          (e) => NameTypeClassComment(
            e.name3!,
            e.bound == null ? null : e.bound.toString(),
            null,
          ),
        ) //
        .toList();

    var allFieldsDistinct = getDistinctFields(allFields, interfaces);

    //if I want to create a copywith from an annotation passed in I could use this
    var typesExplicit = <Interface>[];
    if (!annotation.read('explicitSubTypes').isNull) {
      typesExplicit = annotation
          .read('explicitSubTypes') //
          .listValue
          .map((x) {
            if (x.toTypeValue()?.element is! Element) {
              throw Exception(
                "each type for the copywith def must all be classes",
              );
            }

            var el = x.toTypeValue()!.element!;

            return Interface.fromGenerics(
              (el as InterfaceElement).name!, // or .name
              (el as TypeParameterizedElement).typeParameters
                  .map(
                    (TypeParameterElement x) =>
                        NameType(x.name!, x.bound?.getDisplayString()),
                  )
                  .toList(),
              getAllFields(
                el.allSupertypes,
                el,
              ).where((x) => x.name != 'hashCode').toList(),
              true,
            );
          })
          .toList();
    }

    //all ValueT interfaces of the class, not just those specified in the implements list
    //  we need the ones that are inherited by the implements list
    final allValueTInterfaces =
        // Walk implemented interfaces (and their interfaces)
        flatten<InterfaceType>(ce.interfaces, (x) => x.interfaces)
            // Only keep real classes; avoids casts on mixins/extension types.
            .where((t) => t.element is ClassElement)
            .map((t) {
              final cls =
                  t.element as ClassElement; // also a TypeParameterizedElement2
              final tparams = (cls as TypeParameterizedElement).typeParameters;

              return Interface.fromGenerics(
                cls.name!, // class name
                tparams
                    .map(
                      (TypeParameterElement p) =>
                          NameType(p.name!, p.bound?.getDisplayString()),
                    )
                    .toList(),
                getAllFields(
                  cls.allSupertypes,
                  cls,
                ).where((x) => x.name != 'hashCode').toList(),
              );
            })
            .union(typesExplicit)
            .distinctBy((e) => e.interfaceName)
            .toList();
    ;

    sb.writeln(
      createMorphy(
        isAbstract,
        allFieldsDistinct,
        className,
        docComment ?? "",
        interfaces,
        allValueTInterfaces,
        classGenerics,
        hasConstConstructor,
        annotation.read('generateJson').boolValue,
        annotation.read('hidePublicConstructor').boolValue,
        typesExplicit,
        annotation.read('nonSealed').boolValue,
      ),
    );

    //    sb.writeln(createCopyWith(classDef, otherClasses2).replaceAll("\$", ""));

    // var isOutputCommented = false;
    //
    // var output = isOutputCommented //
    //     ? sb.toString().replaceAll("\n", "\n//")
    //     : sb.toString();

    // return output;

    return sb.toString();
  }
}
