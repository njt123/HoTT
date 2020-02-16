(* -*- mode: coq; mode: visual-line -*- *)
Require Import HoTT.Basics HoTT.Types.
Require Import UnivalenceImpliesFunext EquivalenceVarieties Extensions HProp Fibrations NullHomotopy Pullback.
Require Import HoTT.Tactics PathAny.
Require Import HIT.Coeq Colimits.Pushout.
Require Import Tactics.RewriteModuloAssociativity.

Local Open Scope nat_scope.
Local Open Scope path_scope.

(** * Reflective Subuniverses *)

(** ** References  *)

(** Reflective subuniverses (and modalities) are studied in the following papers, which we will refer to below by their abbreviations:

- The Book: The Homotopy Type Theory Book, chapter 7.  Bare references to "Theorem 7.x.x" are always to the Book.
- RSS: Rijke, Spitters, and Shulman, "Modalities in homotopy type theory", https://arxiv.org/abs/1706.07526.
- CORS: Christensen, Opie, Rijke, and Scoccola, "Localization in Homotopy Type Theory", https://arxiv.org/abs/1807.04155.
*)

(** ** Definitions *)

(** *** Subuniverses *)

Record Subuniverse@{i} :=
{
  In_internal : Type@{i} -> Type@{i} ;
  hprop_inO_internal : Funext -> forall (T : Type@{i}),
      IsHProp (In_internal T) ;
  inO_equiv_inO_internal : forall (T U : Type@{i}) (T_inO : In_internal T)
                                  (f : T -> U) {feq : IsEquiv f},
      In_internal U ;
}.

(** Work around Coq bug that fields of records can't be typeclasses. *)
Class In (O : Subuniverse) (T : Type) := in_internal : In_internal O T.

(** Being in the subuniverse is a mere predicate (by hypothesis).  We include funext in the hypotheses of hprop_inO so that it doesn't have to be assumed in all definitions of (reflective) subuniverses, since in most examples it is required for this and this only.  Here we redefine it using the replaced [In]. *)
Global Instance hprop_inO `{Funext} (O : Subuniverse) (T : Type)
  : IsHProp (In O T)
  := @hprop_inO_internal _ _ T.

(** We assumed repleteness of the subuniverse in the definition.  Of course, with univalence this would be automatic, but we include it as a hypothesis since most of the theory of reflective subuniverses and modalities doesn't need univalence, and most or all examples can be shown to be replete without using univalence.  Here we redefine it using the replaced [In]. *)
Definition inO_equiv_inO {O : Subuniverse} (T : Type) {U : Type}
           `{T_inO : In O T} (f : T -> U) `{IsEquiv T U f}
  : In O U
  := @inO_equiv_inO_internal O T U T_inO f _.

(** The universe of types in the subuniverse *)
Definition Type_@{i j} (O : Subuniverse@{i}) : Type@{j}
  := @sig@{j i} Type@{i} (fun (T : Type@{i}) => In O T).

Coercion TypeO_pr1 O (T : Type_ O) := @pr1 Type (In O) T.

(** The second component of [TypeO] is unique.  *)
Definition path_TypeO@{i j} {fs : Funext} O (T T' : Type_ O) (p : T.1 = T'.1)
  : T = T'
  := path_sigma_hprop@{j i j} T T' p.

Definition equiv_path_TypeO@{i j} {fs : Funext} O (T T' : Type_ O)
: (paths@{j} T.1 T'.1) <~> (T = T')
:= equiv_path_sigma_hprop@{j i j j} T T'.

(** Types in [TypeO] are always in [O]. *)
Global Instance inO_TypeO {O : Subuniverse} (A : Type_ O) : In O A
  := A.2.

Definition inO_equiv_inO' {O : Subuniverse}
           (T : Type) {U : Type} `{In O T} (f : T <~> U)
  : In O U
  := inO_equiv_inO T f.

(** *** Reflections *)

(** A pre-reflection is a map to a type in the subuniverse. *)
Class PreReflects@{i} (O : Subuniverse@{i}) (T : Type@{i}) :=
{
  O_reflector : Type@{i} ;
  O_inO : In O O_reflector ;
  to : T -> O_reflector ;
}.

Arguments O_reflector O T {_}.
Arguments to O T {_}.
Arguments O_inO {O} T {_}.
Global Existing Instance O_inO.

(** It is a reflection if it has the requisite universal property. *)
Class Reflects@{i} (O : Subuniverse@{i}) (T : Type@{i})
      `{PreReflects@{i} O T} :=
{
  extendable_to_O : forall {Q : Type@{i}} {Q_inO : In O Q},
      ooExtendableAlong (to O T) (fun _ => Q)
}.  

Arguments extendable_to_O O {T _ _ Q Q_inO}.

(** Here's a modified version that applies to types in possibly-smaller universes without collapsing those universes to [i]. *)
Definition extendable_to_O'@{i j k} (O : Subuniverse@{i}) (T : Type@{j})
           `{Reflects O T} {Q : Type@{k}} {Q_inO : In O Q}
  : ooExtendableAlong@{j i k i} (to O T) (fun _ => Q).
Proof.
  assert (e := @extendable_to_O O T _ _ Q Q_inO).
  apply (lift_ooextendablealong@{i j j i i i i k k i i}).
  exact e.
Defined.

Record ReflectiveSubuniverse@{i} :=
{
  rsu_subuniv : Subuniverse@{i} ;
  rsu_prereflects : forall (T : Type@{i}), PreReflects rsu_subuniv T ;
  rsu_reflects : forall (T : Type@{i}), Reflects rsu_subuniv T ;
}.

Coercion rsu_subuniv : ReflectiveSubuniverse >-> Subuniverse.
Global Existing Instance rsu_prereflects.
Global Existing Instance rsu_reflects.

(** We allow the name of a subuniverse or modality to be used as the name of its reflector.  This means that when defining a particular example, you should generally put the parametrizing family in a wrapper, so that you can notate the subuniverse as parametrized by, rather than identical to, its parameter.  See Modality.v, Truncations.v, and Localization.v for examples. *)
Definition rsu_reflector (O : ReflectiveSubuniverse) (T : Type) : Type
  := O_reflector O T.

Coercion rsu_reflector : ReflectiveSubuniverse >-> Funclass.

(** *** Recursion principles *)

(** We now extract the recursion principle and the restricted induction principles for paths. *)
Section ORecursion.
  Context {O : Subuniverse} {P Q : Type} {Q_inO : In O Q} `{Reflects O P}.

  Definition O_rec (f : P -> Q)
  : O_reflector O P -> Q
  := (fst (extendable_to_O O 1%nat) f).1.

  Definition O_rec_beta (f : P -> Q) (x : P)
  : O_rec f (to O P x) = f x
  := (fst (extendable_to_O O 1%nat) f).2 x.

  Definition O_indpaths (g h : O_reflector O P -> Q)
             (p : g o to O P == h o to O P)
  : g == h
  := (fst (snd (extendable_to_O O 2) g h) p).1.

  Definition O_indpaths_beta (g h : O_reflector O P -> Q)
             (p : g o (to O P) == h o (to O P)) (x : P)
  : O_indpaths g h p (to O P x) = p x
  := (fst (snd (extendable_to_O O 2) g h) p).2 x.

  Definition O_ind2paths {g h : O_reflector O P -> Q} (p q : g == h)
             (r : p oD (to O P) == q oD (to O P))
  : p == q
  := (fst (snd (snd (extendable_to_O O 3) g h) p q) r).1.

  Definition O_ind2paths_beta {g h : O_reflector O P -> Q} (p q : g == h)
             (r : p oD (to O P) == q oD (to O P)) (x : P)
  : O_ind2paths p q r (to O P x) = r x
  := (fst (snd (snd (extendable_to_O O 3) g h) p q) r).2 x.

  (** Clearly we can continue indefinitely as needed. *)

End ORecursion.

(* We never want to see [extendable_to_O]. *)
Arguments O_rec : simpl never.
Arguments O_rec_beta : simpl never.
Arguments O_indpaths : simpl never.
Arguments O_indpaths_beta : simpl never.
Arguments O_ind2paths : simpl never.
Arguments O_ind2paths_beta : simpl never.

(** Given [Funext], we prove the definition of reflective subuniverse in the book. *)
Global Instance isequiv_o_to_O `{Funext}
       (O : ReflectiveSubuniverse) (P Q : Type) `{In O Q}
: IsEquiv (fun g : O P -> Q => g o to O P)
:= isequiv_ooextendable _ _ (extendable_to_O O).

Definition equiv_o_to_O `{Funext}
           (O : ReflectiveSubuniverse) (P Q : Type) `{In O Q}
: (O P -> Q) <~> (P -> Q)
:= Build_Equiv _ _ (fun g : O P -> Q => g o to O P) _.

(** [isequiv_ooextendable] is defined in a way that makes [O_rec] definitionally equal to the inverse of [equiv_o_to_O]. *)
Global Instance isequiv_O_rec_to_O `{Funext}
       (O : ReflectiveSubuniverse) (P Q : Type) `{In O Q}
  : IsEquiv (fun g : P -> Q => O_rec g)
  := (equiv_isequiv (equiv_o_to_O O P Q)^-1).

(** ** Properties of Reflective Subuniverses *)

(** We now prove a bunch of things about an arbitrary reflective subuniverse. *)
Section Reflective_Subuniverse.
  Context (O : ReflectiveSubuniverse).

  (** Functoriality of [O_rec] homotopies *)
  Definition O_rec_homotopy {P Q : Type} `{In O Q} (f g : P -> Q) (pi : f == g)
  : O_rec (O := O) f == O_rec g.
  Proof.
    srapply O_indpaths; intro x.
    etransitivity.
    { apply O_rec_beta. }
    { etransitivity.
      { exact (pi _). }
      { symmetry; apply O_rec_beta. } }
  Defined.

  (** If [T] is in the subuniverse, then [to O T] is an equivalence. *)
  Definition isequiv_to_O_inO@{u a i} (T : Type@{i}) `{In O T} : IsEquiv@{i i} (to O T).
  Proof.
    (** Using universe annotations to reduce superfluous universes *)
    pose (g := O_rec idmap : O T -> T).
    refine (isequiv_adjointify (to O T) g _ _).
    - refine (O_indpaths (to O T o g) idmap _).
      intros x.
      apply ap.
      apply O_rec_beta.
    - intros x.
      apply O_rec_beta.
  Defined.
  Global Existing Instance isequiv_to_O_inO.

  Definition equiv_to_O (T : Type) `{In O T} : T <~> O T
    := Build_Equiv T (O T) (to O T) _.

  Section Functor.

    (** In this section, we see that [O] is a functor. *)

    Definition O_functor {A B : Type} (f : A -> B) : O A -> O B
      := O_rec (to O B o f).

    (** Naturality of [to O] *)
    Definition to_O_natural {A B : Type} (f : A -> B)
    : (O_functor f) o (to O A) == (to O B) o f
    := (O_rec_beta _).

    (** Functoriality on composition *)
    Definition O_functor_compose {A B C : Type} (f : A -> B) (g : B -> C)
    : (O_functor (g o f)) == (O_functor g) o (O_functor f).
    Proof.
      srapply O_indpaths; intros x.
      refine (to_O_natural (g o f) x @ _).
      transitivity (O_functor g (to O B (f x))).
      - symmetry. exact (to_O_natural g (f x)).
      - apply ap; symmetry.
        exact (to_O_natural f x).
    Defined.

    (** Functoriality on homotopies (2-functoriality) *)
    Definition O_functor_homotopy {A B : Type} (f g : A -> B) (pi : f == g)
    : O_functor f == O_functor g.
    Proof.
      refine (O_indpaths _ _ _); intros x.
      refine (to_O_natural f x @ _).
      refine (_ @ (to_O_natural g x)^).
      apply ap, pi.
    Defined.

    (** Functoriality for inverses of homotopies *)
    Definition O_functor_homotopy_V
               {A B : Type} (f g : A -> B) (pi : f == g)
    : O_functor_homotopy g f (fun x => (pi x)^)
      == fun x => (O_functor_homotopy f g pi x)^.
    Proof.
      refine (O_ind2paths _ _ _); intros x.
      unfold composeD, O_functor_homotopy.
      rewrite !O_indpaths_beta, !ap_V, !inv_pp, inv_V, !concat_p_pp.
      reflexivity.
    Qed.

    (** Hence functoriality on commutative squares *)
    Definition O_functor_square {A B C X : Type} (pi1 : X -> A) (pi2 : X -> B)
               (f : A -> C) (g : B -> C) (comm : (f o pi1) == (g o pi2))
    : ( (O_functor f) o (O_functor pi1) )
      == ( (O_functor g) o (O_functor pi2) ).
    Proof.
      intros x.
      transitivity (O_functor (f o pi1) x).
      - symmetry; rapply O_functor_compose.
      - transitivity (O_functor (g o pi2) x).
        * apply O_functor_homotopy, comm.
        * rapply O_functor_compose.
    Defined.

    (** Functoriality on identities *)
    Definition O_functor_idmap (A : Type)
    : @O_functor A A idmap == idmap.
    Proof.
      refine (O_indpaths _ _ _); intros x.
      apply O_rec_beta.
    Defined.

    (** 3-functoriality, as an example use of [O_ind2paths] *)
    Definition O_functor_2homotopy {A B : Type} {f g : A -> B}
               (p q : f == g) (r : p == q)
    : O_functor_homotopy f g p == O_functor_homotopy f g q.
    Proof.
      refine (O_ind2paths _ _ _); intros x.
      unfold O_functor_homotopy, composeD.
      do 2 rewrite O_indpaths_beta.
      apply whiskerL, whiskerR, ap, r.
    (** Of course, if we wanted to prove 4-functoriality, we'd need to make this transparent. *)
    Qed.

    (** 2-naturality: Functoriality on homotopies is also natural *)
    Definition O_functor_homotopy_beta
               {A B : Type} (f g : A -> B) (pi : f == g) (x : A)
    : O_functor_homotopy f g pi (to O A x)
      = to_O_natural f x
      @ ap (to O B) (pi x)
      @ (to_O_natural g x)^.
    Proof.
      unfold O_functor_homotopy, to_O_natural.
      refine (O_indpaths_beta _ _ _ x @ _).
      refine (concat_p_pp _ _ _).
    Defined.

    (** The pointed endofunctor ([O],[to O]) is well-pointed *)
    Definition O_functor_wellpointed (A : Type)
    : O_functor (to O A) == to O (O A).
    Proof.
      refine (O_indpaths _ _ _); intros x.
      apply to_O_natural.
    Defined.

    (** "Functoriality of naturality": the pseudonaturality axiom for composition *)
    Definition to_O_natural_compose {A B C : Type}
               (f : A -> B) (g : B -> C) (a : A)
    : ap (O_functor g) (to_O_natural f a)
      @ to_O_natural g (f a)
      = (O_functor_compose f g (to O A a))^
      @ to_O_natural (g o f) a.
    Proof.
      unfold O_functor_compose, to_O_natural.
      rewrite O_indpaths_beta.
      rewrite !inv_pp, ap_V, !inv_V, !concat_pp_p.
      rewrite concat_Vp, concat_p1; reflexivity.
    Qed.

    (** The pseudofunctoriality axiom *)
    Definition O_functor_compose_compose
               {A B C D : Type} (f : A -> B) (g : B -> C) (h : C -> D)
               (a : O A)
    : O_functor_compose f (h o g) a
      @ O_functor_compose g h (O_functor f a)
      = O_functor_compose (g o f) h a
        @ ap (O_functor h) (O_functor_compose f g a).
    Proof.
      revert a; refine (O_ind2paths _ _ _).
      intros a; unfold composeD, O_functor_compose; cbn.
      Open Scope long_path_scope.
      rewrite !O_indpaths_beta, !ap_pp, !ap_V, !concat_p_pp.
      refine (whiskerL _ (apD _ (to_O_natural f a)^)^ @ _).
      rewrite O_indpaths_beta.
      rewrite transport_paths_FlFr, !concat_p_pp.
      rewrite !ap_V, inv_V.
      rewrite !concat_pV_p.
      apply whiskerL. apply inverse2.
      apply ap_compose.
      Close Scope long_path_scope.
    Qed.

    (** Preservation of equivalences *)
    Global Instance isequiv_O_functor {A B : Type} (f : A -> B) `{IsEquiv _ _ f}
    : IsEquiv (O_functor f).
    Proof.
      refine (isequiv_adjointify (O_functor f) (O_functor f^-1) _ _).
      - intros x.
        refine ((O_functor_compose _ _ x)^ @ _).
        refine (O_functor_homotopy _ idmap _ x @ _).
        + intros y; apply eisretr.
        + apply O_functor_idmap.
      - intros x.
        refine ((O_functor_compose _ _ x)^ @ _).
        refine (O_functor_homotopy _ idmap _ x @ _).
        + intros y; apply eissect.
        + apply O_functor_idmap.
    Defined.

    Definition equiv_O_functor {A B : Type} (f : A <~> B)
    : O A <~> O B
    := Build_Equiv _ _ (O_functor f) _.

    (** This is sometimes useful to have a separate name for, to facilitate rewriting along it. *)
    Definition to_O_equiv_natural {A B} (f : A <~> B)
    : (equiv_O_functor f) o (to O A) == (to O B) o f
    := to_O_natural f.

    (** This corresponds to [ap O] on the universe. *)
    Definition ap_O_path_universe' `{Univalence}
               {A B : Type} (f : A <~> B)
    : ap O (path_universe_uncurried f)
      = path_universe_uncurried (equiv_O_functor f).
    Proof.
      revert f.
      equiv_intro (equiv_path A B) p.
      refine (ap (ap O) (eta_path_universe p) @ _).
      destruct p; simpl.
      apply moveL_equiv_V.
      apply path_equiv, path_arrow, O_indpaths; intros x.
      symmetry; apply to_O_natural.
    Defined.

    Definition ap_O_path_universe `{Univalence}
               {A B : Type} (f : A -> B) `{IsEquiv _ _ f}
    : ap O (path_universe f) = path_universe (O_functor f)
    := ap_O_path_universe' (Build_Equiv _ _ f _).

    (** Postcomposition respects [O_rec] *)
    Definition O_rec_postcompose {A B C : Type@{i}} `{In O B} {C_inO : In O C}
               (f : A -> B) (g : B -> C)
    : g o O_rec (O := O) f == O_rec (O := O) (g o f).
    Proof.
      refine (O_indpaths _ _ _); intros x.
      transitivity (g (f x)).
      - apply ap. apply O_rec_beta.
      - symmetry. exact (O_rec_beta (g o f) x).
    Defined.

  End Functor.

  Section Replete.

    (** An equivalent formulation of repleteness is that a type lies in the subuniverse as soon as its unit map is an equivalence. *)
    Definition inO_isequiv_to_O (T:Type)
    : IsEquiv (to O T) -> In O T
    := fun _ => inO_equiv_inO (O T) (to O T)^-1.

    (* We don't make this an ordinary instance, but we allow it to solve [In O] constraints if we already have [IsEquiv] as a hypothesis.  *)
    Hint Immediate inO_isequiv_to_O : typeclass_instances.

    Definition inO_iff_isequiv_to_O (T:Type)
    : In O T <-> IsEquiv (to O T).
    Proof.
      split; exact _.
    Defined.

    (** Thus, [T] is in a subuniverse as soon as [to O T] admits a retraction. *)
    Definition inO_to_O_retract (T:Type) (mu : O T -> T)
    : Sect (to O T) mu -> In O T.
    Proof.
      unfold Sect; intros H.
      apply inO_isequiv_to_O.
      apply isequiv_adjointify with (g:=mu).
      - refine (O_indpaths (to O T o mu) idmap _).
        intros x; exact (ap (to O T) (H x)).
      - exact H.
    Defined.

  End Replete.

  Section OInverts.

    (** The maps that are inverted by the reflector.  Note that this notation is NOT (yet) GLOBAL; it only exists in this section. *)
    Local Notation O_inverts f := (IsEquiv (O_functor f)).

    Global Instance O_inverts_O_unit (A : Type)
    : O_inverts (to O A).
    Proof.
      refine (isequiv_homotopic (to O (O A)) _).
      intros x; symmetry; apply O_functor_wellpointed.
    Defined.

    (** A map between modal types that is inverted by [O] is already an equivalence.  This can't be an [Instance], probably because it causes an infinite regress applying more and more [O_functor]. *)
    Definition isequiv_O_inverts {A B : Type} `{In O A} `{In O B}
      (f : A -> B) `{O_inverts f}
    : IsEquiv f.
    Proof.
      refine (isequiv_commsq' f (O_functor f) (to O A) (to O B) _).
      apply to_O_natural.
    Defined.

    (** Strangely, even this seems to cause infinite loops *)
    (** [Hint Immediate isequiv_O_inverts : typeclass_instances.] *)

    Definition equiv_O_inverts {A B : Type} `{In O A} `{In O B}
      (f : A -> B) `{O_inverts f}
    : A <~> B
    := Build_Equiv _ _ f (isequiv_O_inverts f).

    Definition isequiv_O_rec_O_inverts
           {A B : Type} `{In O B} (f : A -> B) `{O_inverts f}
    : IsEquiv (O_rec (O := O) f).
    Proof.
      apply isequiv_O_inverts.
      refine (cancelR_isequiv (O_functor (to O A))).
      refine (isequiv_homotopic (O_functor (O_rec f o to O A))
                                (O_functor_compose _ _)).
      refine (isequiv_homotopic (O_functor f)
               (O_functor_homotopy _ _ (fun x => (O_rec_beta f x)^))).
    Defined.

    (** If [f] is inverted by [O], then mapping out of it into any modal type is an equivalence.  First we prove a version not requiring funext.  For use in [O_inverts_O_leq] below, we allow the types [A], [B], and [Z] to perhaps live in smaller universes than the one [i] on which our subuniverse lives. *)
    Definition ooextendable_O_inverts@{a b z i}
               {A : Type@{a}} {B : Type@{b}} (f : A -> B) `{O_inverts f}
               (Z : Type@{z}) `{In@{i} O Z}
      : ooExtendableAlong@{a b z i} f (fun _ => Z).
    Proof.
      refine (cancelL_ooextendable@{a b i z i i i i i} _ _ (to O B) _ _).
      1:exact (extendable_to_O'@{i b z} O B).
      refine (ooextendable_homotopic _ (O_functor f o to O A) _ _).
      1:apply to_O_natural.
      refine (ooextendable_compose _ (to O A) (O_functor f) _ _).
      - srapply ooextendable_equiv.
      - exact (extendable_to_O'@{i a z} O A).
    Defined.

    (** And now the funext version *)
    Definition isequiv_precompose_O_inverts `{Funext}
               {A B : Type} (f : A -> B) `{O_inverts f}
               (Z : Type) `{In O Z}
      : IsEquiv (fun g:B->Z => g o f).
    Proof.
      srapply (equiv_extendable_isequiv 0).
      exact (ooextendable_O_inverts f Z 2).
    Defined.

    (** Conversely, if a map is inverted by the representable functor [? -> Z] for all [O]-modal types [Z], then it is inverted by [O].  As before, first we prove a version that doesn't require funext. *)
    Definition O_inverts_from_extendable
               {A : Type@{i}} {B : Type@{j}} (f : A -> B)
               (** Without the universe annotations, the result ends up insufficiently polymorphic. *)
               (e : forall (Z:Type@{k}), In O Z -> ExtendableAlong@{i j k l} 2 f (fun _ => Z))
      : O_inverts f.
    Proof.
      srapply isequiv_adjointify.
      - exact (O_rec (fst (e (O A) _) (to O A)).1).
      - srapply O_indpaths. intros b.
        rewrite O_rec_beta.
        assert (e1 := fun h k => fst (snd (e (O B) _) h k)). cbn in e1.
        refine ((e1 (fun y => O_functor f ((fst (e (O A) _) (to O A)).1 y)) (to O B) _).1 b).
        intros a.
        rewrite ((fst (e (O A) (O_inO A)) (to O A)).2 a).
        apply to_O_natural.
      - srapply O_indpaths. intros a.
        rewrite to_O_natural, O_rec_beta.
        exact ((fst (e (O A) (O_inO A)) (to O A)).2 a).
    Defined.

    (** And the version with funext.  Use it with universe parameters [i j k l lplus l l l l]. *)
    Definition O_inverts_from_isequiv_precompose `{Funext}
               {A B : Type} (f : A -> B)
               (e : forall (Z:Type), In O Z -> IsEquiv (fun g:B->Z => g o f))
      : O_inverts f.
    Proof.
      apply O_inverts_from_extendable.
      intros Z ?.
      apply (equiv_extendable_isequiv 0 _ _)^-1.
      rapply e.
    Defined.

    (** The converse is also true.  This the first half of Lemma 1.23 of RSS. *)
    Definition ooextendable_O_inverts
               {A B : Type} (f : A -> B) `{O_inverts f}
               (Z : Type) `{In O Z}
      : ooExtendableAlong f (fun _ => Z).
    Proof.
      refine (cancelL_ooextendable _ _ (to O B) _ _).
      1:srapply extendable_to_O.
      refine (ooextendable_homotopic _ (O_functor f o to O A) _ _).
      1:apply to_O_natural.
      refine (ooextendable_compose _ (to O A) (O_functor f) _ _).
      2:srapply extendable_to_O.
      srapply ooextendable_equiv.
    Defined.

    (** And now the funext version *)
    Definition isequiv_precompose_O_inverts `{Funext}
               {A B : Type} (f : A -> B) `{O_inverts f}
               (Z : Type) `{In O Z}
      : IsEquiv (fun g:B->Z => g o f).
    Proof.
      srapply (equiv_extendable_isequiv 0).
      exact (ooextendable_O_inverts f Z 2).
    Defined.

    (** This property also characterizes the types in the subuniverse, which is the other half of Lemma 1.23. *)
    Definition inO_ooextendable_O_inverts (Z:Type@{k})
               (E : forall (A : Type@{i}) (B : Type@{j}) (f : A -> B)
                      (Oif : O_inverts f),
                   ooExtendableAlong f (fun _ => Z))
      : In@{Ou Oa k} O Z.
    Proof.
      pose (EZ := fst (E Z (O Z) (to O Z) _ 1%nat) idmap).
      exact (inO_to_O_retract _ EZ.1 EZ.2).
    Defined.

    (** A version with the equivalence form of the extension condition. *)
    Definition inO_isequiv_precompose_O_inverts (Z:Type)
               (Yo : forall (A : Type) (B : Type) (f : A -> B)
                       (Oif : O_inverts f),
                   IsEquiv (fun g:B->Z => g o f))
      : In O Z.
    Proof.
      pose (EZ := extension_isequiv_precompose (to O Z) _ (Yo Z (O Z) (to O Z) _) idmap).
      exact (inO_to_O_retract _ EZ.1 EZ.2).
    Defined.

    Definition to_O_inv_natural {A B : Type} `{In O A} `{In O B}
               (f : A -> B)
    : (to O B)^-1 o (O_functor f) == f o (to O A)^-1.
    Proof.
      refine (O_indpaths _ _ _); intros x.
      apply moveR_equiv_V.
      refine (to_O_natural f x @ _).
      do 2 apply ap.
      symmetry; apply eissect.
    Defined.

    (** Two maps between modal types that become equal after applying [O_functor] are already equal. *)
    Definition O_functor_faithful_inO {A B : Type} `{In O A} `{In O B}
      (f g : A -> B) (e : O_functor f == O_functor g)
      : f == g.
    Proof.
      intros x.
      refine (ap f (eissect (to O A) x)^ @ _).
      refine (_ @ ap g (eissect (to O A) x)).
      transitivity ((to O B)^-1 (O_functor f (to O A x))).
      + symmetry; apply to_O_inv_natural.
      + transitivity ((to O B)^-1 (O_functor g (to O A x))).
        * apply ap, e.
        * apply to_O_inv_natural.
    Defined.

    (** Any map to a type in the subuniverse that is inverted by [O] must be equivalent to [to O].  More precisely, the type of such maps is contractible. *)
    Definition typeof_to_O (A : Type)
      := { OA : Type & { Ou : A -> OA & ((In O OA) * (O_inverts Ou)) }}.

    Global Instance contr_typeof_O_unit `{Univalence} (A : Type)
    : Contr (typeof_to_O A).
    Proof.
      exists (O A ; (to O A ; (_ , _))).
      intros [OA [Ou [? ?]]].
      pose (f := O_rec Ou : O A -> OA).
      pose (g := (O_functor Ou)^-1 o to O OA : (OA -> O A)).
      assert (IsEquiv f).
      { refine (isequiv_adjointify f g _ _).
        - apply O_functor_faithful_inO; intros x.
          rewrite O_functor_idmap.
          rewrite O_functor_compose.
          unfold g.
          rewrite (O_functor_compose (to O OA) (O_functor Ou)^-1).
          rewrite O_functor_wellpointed.
          rewrite (to_O_natural (O_functor Ou)^-1 x).
          refine (to_O_natural f _ @ _).
          set (y := (O_functor Ou)^-1 x).
          transitivity (O_functor Ou y); try apply eisretr.
          unfold f, O_functor.
          apply O_rec_postcompose.
        - refine (O_indpaths _ _ _); intros x.
          unfold f.
          rewrite O_rec_beta. unfold g.
          apply moveR_equiv_V.
          symmetry; apply to_O_natural.
      }
      simple refine (path_sigma _ _ _ _ _); cbn.
      - exact (path_universe f).
      - rewrite transport_sigma.
        simple refine (path_sigma _ _ _ _ _); cbn; try apply path_ishprop.
        apply path_arrow; intros x.
        rewrite transport_arrow_fromconst.
        rewrite transport_path_universe.
        unfold f; apply O_rec_beta.
    Qed.

  End OInverts.

  Section Types.

    (** ** The [Unit] type *)
    Global Instance inO_unit : In O Unit.
    Proof.
      apply inO_to_O_retract with (mu := fun x => tt).
      exact (@contr Unit _).
    Defined.

    (** It follows that any contractible type is in [O]. *)
    Global Instance inO_contr {A : Type} `{Contr A} : In O A.
    Proof.
      exact (inO_equiv_inO Unit equiv_contr_unit^-1).
    Defined.

    (** And that the reflection of a contractible type is still contractible. *)
    Global Instance contr_O_contr {A : Type} `{Contr A} : Contr (O A).
    Proof.
      exact (contr_equiv A (to O A)).
    Defined.

    (** ** Dependent product and arrows *)
    (** Theorem 7.7.2 *)
    Global Instance inO_forall {fs : Funext} (A:Type) (B:A -> Type)
    : (forall x, (In O (B x)))
      -> (In O (forall x:A, (B x))).
    Proof.
      intro H.
      pose (ev := fun x => (fun (f:(forall x, (B x))) => f x)).
      pose (zz := fun x:A => O_rec (O := O) (ev x)).
      apply inO_to_O_retract with (mu := fun z => fun x => zz x z).
      intro phi.
      unfold zz, ev; clear zz; clear ev.
      apply path_forall; intro x.
      exact (O_rec_beta (fun f : forall x0, (B x0) => f x) phi).
    Defined.

    Global Instance inO_arrow {fs : Funext} (A B : Type) `{In O B}
    : In O (A -> B).
    Proof.
      apply inO_forall.
      intro a. exact _.
    Defined.

    (** ** Product *)
    Global Instance inO_prod (A B : Type) `{In O A} `{In O B}
    : In O (A*B).
    Proof.
      apply inO_to_O_retract with
        (mu := fun X => (@O_rec _ (A * B) A _ _ _ fst X , O_rec snd X)).
      intros [a b]; apply path_prod; simpl.
      - exact (O_rec_beta fst (a,b)).
      - exact (O_rec_beta snd (a,b)).
    Defined.

    (** We show that [OA*OB] has the same universal property as [O(A*B)] *)

    Definition equiv_O_prod_unit_precompose
               {fs : Funext} (A B C : Type) `{In O C}
    : ((O A) * (O B) -> C) <~> (A * B -> C).
    Proof.
      refine (equiv_uncurry A B C oE _).
      refine (_ oE (equiv_uncurry (O A) (O B) C)^-1).
      refine (equiv_o_to_O O A (B -> C) oE _); simpl.
      apply equiv_postcompose'.
      exact (equiv_o_to_O _ B C).
    Defined.

    (** The preceding equivalence turns out to be actually (judgmentally!) precomposition with the following function. *)
    Definition O_prod_unit (A B : Type) : A * B -> O A * O B
      := functor_prod (to O A) (to O B).

    (** From this, we can define the comparison map for products, and show that precomposing with it is also an equivalence. *)
    Definition O_prod_cmp (A B : Type) : O (A * B) -> O A * O B
      := O_rec (O_prod_unit A B).

    Global Instance isequiv_O_prod_cmp (A B : Type)
    : IsEquiv (O_prod_cmp A B).
    Proof.
      simple refine (isequiv_adjointify _ _ _ _).
      { apply prod_ind; intro a.
        apply O_rec; intro b; revert a.
        apply O_rec; intro a.
        apply (to O).
        exact (a, b). }
      { unfold prod_ind, O_prod_cmp, O_prod_unit.
        intros [oa ob].
        revert ob; refine (O_indpaths _ _ _); intros b.
        revert oa; refine (O_indpaths _ _ _); intros a.
        cbn. abstract (repeat rewrite O_rec_beta; reflexivity). }
      { unfold prod_ind, O_prod_cmp, O_prod_unit.
        refine (O_indpaths _ _ _); intros [a b]; cbn.
        abstract (repeat (rewrite O_rec_beta; cbn); reflexivity). }
    Defined.

    Definition isequiv_O_prod_cmp_precompose
      {fs : Funext} (A B C : Type) {C_inO : In O C}
    : IsEquiv (fun h : O A * O B -> C => h o O_prod_cmp A B).
    Proof.
      apply isequiv_precompose; exact _.
    Defined.

    Definition equiv_O_prod_cmp (A B : Type)
    : O (A * B) <~> (O A * O B)
    := Build_Equiv _ _ (O_prod_cmp A B) _.

    (** ** Pullbacks *)

    Global Instance inO_pullback {A B C} (f : B -> A) (g : C -> A)
           `{In O A} `{In O B} `{In O C}
      : In O (Pullback f g).
    Proof.
      srapply inO_to_O_retract.
      - intros op.
        exists (O_rec pr1 op).
        exists (O_rec (fun p => p.2.1) op).
        revert op; apply O_indpaths; intros [b [c a]].
        refine (ap f (O_rec_beta _ _) @ _); cbn.
        refine (a @ ap g (O_rec_beta _ _)^).
      - intros [b [c a]]; cbn.
        srapply path_sigma'.
        { apply O_rec_beta. }
        refine (transport_sigma' _ _ @ _); cbn.
        srapply path_sigma'.
        { apply O_rec_beta. }
        abstract (
          rewrite transport_paths_Fr;
          rewrite transport_paths_Fl;
          rewrite O_indpaths_beta;
          rewrite concat_V_pp;
          rewrite ap_V;
          apply concat_pV_p ).
    Defined.

    (** ** Fibers *)

    Global Instance inO_hfiber {A B : Type} `{In O A} `{In O B}
           (f : A -> B) (b : B)
    : In O (hfiber f b).
    Proof.
      simple refine (inO_to_O_retract _ _ _).
      - intros x; simple refine (_;_).
        + exact (O_rec pr1 x).
        + revert x; apply O_indpaths; intros x; simpl.
          refine (ap f (O_rec_beta pr1 x) @ _).
          exact (x.2).
      - intros [a p]; simple refine (path_sigma' _ _ _).
        + exact (O_rec_beta pr1 (a;p)).
        + refine (ap (transport _ _) (O_indpaths_beta _ _ _ _) @ _); simpl.
          refine (transport_paths_Fl _ _ @ _).
          apply concat_V_pp.
    Defined.

    Definition inO_unsigma {A : Type} (B : A -> Type)
               `{In O A} {B_inO : In O {x:A & B x}} (x : A)
    : In O (B x).
    Proof.
      refine (inO_equiv_inO _ (hfiber_fibration x B)^-1).
      (** TODO: Why doesn't Coq find this instance? *)
      refine (inO_hfiber pr1 x); assumption.
    Defined.

    Hint Immediate inO_unsigma : typeclass_instances.

    (** The reflector preserving hfibers is a characterization of lex modalities.  Here is the comparison map. *)
    Definition O_functor_hfiber {A B} (f : A -> B) (b : B)
    : O (hfiber f b) -> hfiber (O_functor f) (to O B b).
    Proof.
      apply O_rec. intros [a p].
      exists (to O A a).
      refine (to_O_natural f a @ _).
      apply ap, p.
    Defined.

    (** Theorem 7.3.9: The reflector [O] can be discarded inside a reflected sum. *)
    Definition equiv_O_sigma_O {A} (P : A -> Type)
    : O {x:A & O (P x)} <~> O {x:A & P x}.
    Proof.
      simple refine (equiv_adjointify _ _ _ _).
      - apply O_rec; intros [a op]; revert op.
        apply O_rec; intros p.
        exact (to O _ (a;p)).
      - apply O_rec; intros [a p].
        exact (to O _ (a ; to O _ p)).
      - unfold Sect; apply O_indpaths; try exact _.
        intros [a p]; simpl.
        abstract (repeat (simpl rewrite @O_rec_beta); reflexivity).
      - unfold Sect; apply O_indpaths; try exact _.
        intros [a op]; revert op; apply O_indpaths; try exact _; intros p; simpl.
        abstract (repeat (simpl rewrite @O_rec_beta); reflexivity).
    Defined.

    (** ** Equivalences *)

    (** Naively it might seem that we need closure under Sigmas (hence a modality) to deduce closure under [Equiv], but in fact the above closure under fibers is sufficient.  This appears as part of the proof of Proposition 2.18 of CORS.  For later use, we try to reduce the number of universe parameters (but we don't completely control them all). *)
    Global Instance inO_equiv `{Funext} (A : Type@{i}) (B : Type@{j})
           `{In O A} `{In O B}
      : In O (A <~> B).
    Proof.
      refine (inO_equiv_inO _ (issig_equiv@{i j k} A B)).
      refine (inO_equiv_inO _ (equiv_functor_sigma equiv_idmap@{k}
                                 (fun f => equiv_biinv_isequiv@{i j k l} f))).
      transparent assert (c : (prod@{k k} (A->B) (prod@{k k} (B->A) (B->A)) -> prod@{k k} (A -> A) (B -> B))).
      { intros [f [g h]]; exact (h o f, f o g). }
      pose (U := hfiber@{k k} c (idmap, idmap)).
      refine (inO_equiv_inO'@{k k k} U _). (** Introduces some extra copies of [k] by typeclass inference. *)
      unfold hfiber, BiInv; cbn in *.
      srefine (equiv_adjointify _ _ _ _).
      - intros [[f [g h]] p].
        apply (equiv_inverse (equiv_path_prod _ _)) in p.
        destruct p as [p q]; cbn in *.
        exists f; split; [ exists h | exists g ].
        all:apply ap10; assumption.
      - intros [f [[g p] [h q]]].
        exists (f,(h,g)); cbn.
        apply path_prod; apply path_arrow; assumption.
      - intros [f [[g p] [h q]]]; cbn.
        apply (path_sigma' _ 1); apply path_prod; apply (path_sigma' _ 1);
          cbn; rewrite transport_1.
        1:rewrite ap_fst_path_prod.
        2:rewrite ap_snd_path_prod.
        all:apply path_forall; intros x; rewrite ap10_path_arrow; reflexivity.
      - intros [[f [g h]] p]; cbn. 
        apply (path_sigma' _ 1); cbn.
        refine (_ @ eta_path_prod p); apply ap011; apply eta_path_arrow.
    Defined.

    (** ** Paths *)

    Definition inO_paths@{i j} (S : Type@{i}) {S_inO : In O S} (x y : S)
    : In O (x=y).
    Proof.
      simple refine (inO_to_O_retract@{i} _ _ _); intro u.
      - assert (p : (fun _ : O (x=y) => x) == (fun _=> y)).
        { refine (O_indpaths _ _ _); simpl.
          intro v; exact v. }
        exact (p u).
      - simpl.
        rewrite O_indpaths_beta; reflexivity.
    Qed.
    Global Existing Instance inO_paths.

    (** ** Truncations  *)

    (** The reflector preserves hprops (and, as we have already seen, contractible types), although it doesn't generally preserve [n]-types for other [n]. *)
    Global Instance ishprop_O_ishprop {A} `{IsHProp A} : IsHProp (O A).
    Proof.
      refine ishprop_isequiv_diag.
      refine (isequiv_homotopic (O_prod_cmp A A
                               o O_functor (fun (a:A) => (a,a))) _).
      apply O_indpaths; intros x; simpl.
      refine (ap (O_prod_cmp A A) (to_O_natural (fun (a:A) => (a,a)) x) @ _).
      unfold O_prod_cmp; apply O_rec_beta.
    Defined.

    (** If [A] is [In O], then so is [IsTrunc n A]. *)
    Global Instance inO_istrunc `{Funext} {n} {A} `{In O A}
    : In O (IsTrunc n A).
    Proof.
      generalize dependent A; simple_induction n n IH; intros A ?.
      - (** We have to be slightly clever here: the actual definition of [Contr] involves a sigma, which [O] is not generally closed under, but fortunately we have [equiv_contr_inhabited_allpath]. *)
        refine (inO_equiv_inO _ equiv_contr_inhabited_allpath^-1).
      - change (In O (forall x y:A, IsTrunc n (x=y))).
        exact _.
    Defined.

    (** ** Coproducts *)

    Definition equiv_O_sum {A B} :
      O (A + B) <~> O (O A + O B).
    Proof.
      simple refine (equiv_adjointify _ _ _ _).
      - apply O_rec; intros x.
        exact (to O _ (functor_sum (to O A) (to O B) x)).
      - apply O_rec; intros [x|x].
        + (* Work around https://coq.inria.fr/bugs/show_bug.cgi?id=4525, stack overflow in exact *)
          let lem := constr:(fun A B => to O _ o @inl A B) in
          exact (O_rec (lem _ _) x).
        + let lem := constr:(fun A B => to O _ o @inr A B) in
          exact (O_rec (lem _ _) x).
      - apply O_indpaths; intros [x|x].
        all:revert x; apply O_indpaths; intros x.
        all:abstract (rewrite !O_rec_beta; reflexivity).
      - apply O_indpaths; intros [x|x].
        all:abstract (rewrite !O_rec_beta; cbn;
                      rewrite !O_rec_beta; reflexivity).
    Defined.

    (** ** Coequalizers *)

    Section OCoeq.
      Context {B A : Type} (f g : B -> A).

      Definition O_coeq_cmp
      : O (Coeq f g) -> O (Coeq (O_functor f) (O_functor g)).
      Proof.
        apply O_functor.
        exact (functor_coeq (to O B) (to O A)
                            (fun y => (to_O_natural f y)^)
                            (fun y => (to_O_natural g y)^)).
      Defined.

      Definition O_coeq_cmp_inverse
      : O (Coeq (O_functor f) (O_functor g)) -> O (Coeq f g).
      Proof.
        apply O_rec; simple refine (Coeq_rec _ _ _).
        - apply O_functor, coeq.
        - intros b.
          refine ((O_functor_compose f coeq b)^ @ _).
          refine (_ @ (O_functor_compose g coeq b)).
          apply O_functor_homotopy.
          intros z; apply cglue.
      Defined.

      Local Definition O_coeq_cmp_eisretr
      : Sect O_coeq_cmp_inverse O_coeq_cmp.
      Proof.
        unfold O_coeq_cmp, O_coeq_cmp_inverse.
        apply O_indpaths; intros z.
        rewrite O_rec_beta.
        revert z; simple refine (Coeq_ind _ _ _).
        - cbn; intros a.
          refine ((O_functor_compose _ _ _)^ @ _); cbn.
          revert a; apply O_indpaths, to_O_natural.
        - set (coeq_to :=
                 functor_coeq (to O B) (to O A)
                              (fun y : B => (to_O_natural f y)^)
                              (fun y : B => (to_O_natural g y)^)).
          apply O_ind2paths; intros b; unfold composeD; cbn.
          rewrite transport_paths_FlFr, concat_pp_p; apply moveR_Vp.
          rewrite <- (apD (O_indpaths _ _ _) (to_O_natural f b)^).
          rewrite <- (apD (O_indpaths _ _ _) (to_O_natural g b)^).
          rewrite !O_indpaths_beta, !transport_paths_FlFr.
          Open Scope long_path_scope.
          rewrite !ap_V, !inv_V, !concat_p_pp.
          rewrite (ap_compose _ (O_functor coeq_to)).
          rewrite Coeq_rec_beta_cglue.
          rewrite !ap_pp, !concat_p_pp.
          unfold O_functor_homotopy; rewrite O_indpaths_beta.
          rewrite !ap_pp, !concat_p_pp.
          pose (p := O_functor_compose_compose g coeq coeq_to (to O B b)).
          apply moveL_pV in p; rewrite concat_pp_p in p; apply moveR_Vp in p.
          rewrite@A <- p. clear p.
          rewrite@A (to_O_natural_compose g
                       (fun x => @coeq _ _ (O_functor f) (O_functor g)
                                       (to O A x)) b).
          rewrite concat_pp_V.
          rewrite@A (to_O_natural_compose f
                     (fun x => @coeq _ _ (O_functor f) (O_functor g)
                                     (to O A x)) b).
          rewrite <- inv_pp.
          rewrite (O_functor_compose_compose f coeq coeq_to (to O B b)).
          rewrite inv_pp, ap_V.
          rewrite !concat_pp_p; apply whiskerL; rewrite !concat_p_pp.
          (** The trick here is to notice that [(fun x => coeq (to O A (f x)))] is definitionally equal to [(fun x => coeq_to (coeq (f x)))]. *)
          rewrite <- (to_O_natural_compose
                        (fun x => coeq (f x)) coeq_to b).
          rewrite <- ap_compose.
          rewrite !concat_pp_p; apply whiskerL, moveR_Mp; rewrite !concat_p_pp.
          rewrite <- (concat_Ap (fun x => (to_O_natural coeq_to x)^) (cglue b)).
          rewrite !concat_pp_p; apply moveL_Mp; rewrite !concat_p_pp.
          rewrite ap_V, <- !inv_pp, @to_O_natural_compose.
          rewrite concat_p_Vp, concat_Vp, concat_1p.
          rewrite (ap_compose coeq_to (to O (Coeq (O_functor f) (O_functor g)))).
          subst coeq_to; rewrite functor_coeq_beta_cglue.
          rewrite !ap_pp, <- !ap_compose, !inv_pp, !concat_p_pp, !ap_V, !inv_V.
          rewrite concat_pp_V, concat_pV_p; reflexivity.
          Close Scope long_path_scope.
      Qed.

      Local Definition O_coeq_cmp_eissect
      : Sect O_coeq_cmp O_coeq_cmp_inverse.
      Proof.
        unfold O_coeq_cmp, O_coeq_cmp_inverse.
        apply O_indpaths; intros z.
        rewrite to_O_natural, O_rec_beta.
        revert z; simple refine (Coeq_ind _ _ _).
        - intros a. cbn.
          apply to_O_natural.
        - intros b; cbn.
          rewrite transport_paths_FlFr, ap_compose.
          rewrite functor_coeq_beta_cglue.
          rewrite !ap_pp, <- !ap_compose; cbn.
          rewrite Coeq_rec_beta_cglue.
          Open Scope long_path_scope.
          rewrite !inv_pp, !concat_p_pp, !ap_V, !inv_V.
          apply moveR_pM; rewrite !concat_pp_p.
          rewrite (to_O_natural_compose f (@coeq B A f g) b).
          rewrite concat_p_Vp.
          rewrite <- O_functor_homotopy_V.
          rewrite O_functor_homotopy_beta.
          rewrite concat_pV_p, !concat_p_pp, ap_V; apply whiskerR.
          rewrite !concat_pp_p; apply moveR_Vp.
          symmetry; apply to_O_natural_compose.
          Close Scope long_path_scope.
      Qed.

      Global Instance isequiv_O_coeq_cmp
      : IsEquiv O_coeq_cmp
        := isequiv_adjointify _ O_coeq_cmp_inverse
                              O_coeq_cmp_eisretr O_coeq_cmp_eissect.

      Definition equiv_O_coeq
      : O (Coeq f g) <~> O (Coeq (O_functor f) (O_functor g))
        := Build_Equiv _ _ O_coeq_cmp _.

      Definition equiv_O_coeq_to_O (a : A)
        : equiv_O_coeq (to O (Coeq f g) (coeq a))
          = to O (Coeq (O_functor f) (O_functor g)) (coeq (to O A a)).
      Proof.
        refine (to_O_natural _ _).
      Defined.

      Definition inverse_equiv_O_coeq_to_O (a : A)
        : equiv_O_coeq^-1 (to O (Coeq (O_functor f) (O_functor g)) (coeq (to O A a)))
          = to O (Coeq f g) (coeq a).
      Proof.
        apply moveR_equiv_V; symmetry; apply equiv_O_coeq_to_O.
      Defined.

    End OCoeq.

    (** ** Pushouts *)

    Section OPushout.
      Context {A B C : Type} (f : A -> B) (g : A -> C).

      Definition equiv_O_pushout
        : O (Pushout f g) <~> O (Pushout (O_functor f) (O_functor g)).
      Proof.
        unfold Pushout.
        refine (_ oE equiv_O_coeq (inl o f) (inr o g)).
        refine ((equiv_O_coeq _ _)^-1 oE _).
        apply equiv_O_functor.
        srefine (@equiv_functor_coeq'
                   _ _ (O_functor (inl o f)) (O_functor (inr o g))
                   _ _ (O_functor (inl o O_functor f))
                   (O_functor (inr o O_functor g)) _ _ _ _).
        - apply equiv_to_O; exact _.
        - apply equiv_O_sum.
        - srefine (O_indpaths _ _ _); intros a; cbn.
          abstract (rewrite !to_O_natural, O_rec_beta; reflexivity).
        - srefine (O_indpaths _ _ _); intros a; cbn.
          abstract (rewrite !to_O_natural, O_rec_beta; reflexivity).
      Defined.

      Definition equiv_O_pushout_to_O_pushl (b : B)
        : equiv_O_pushout (to O (Pushout f g) (pushl b))
          = to O (Pushout (O_functor f) (O_functor g)) (pushl (to O B b)).
      Proof.
        cbn.
        unfold O_coeq_cmp, O_coeq_cmp_inverse, Pushout, pushl, push.
        rewrite to_O_natural.
        rewrite to_O_natural.
        rewrite O_rec_beta.
        cbn.
        rewrite O_rec_beta.
        rewrite to_O_natural.
        reflexivity.
      Qed.

      Definition equiv_O_pushout_to_O_pushr (c : C)
        : equiv_O_pushout (to O (Pushout f g) (pushr c))
          = to O (Pushout (O_functor f) (O_functor g)) (pushr (to O C c)).
      Proof.
        cbn.
        unfold O_coeq_cmp, O_coeq_cmp_inverse, Pushout, pushr, push.
        rewrite to_O_natural.
        rewrite to_O_natural.
        rewrite O_rec_beta.
        cbn.
        rewrite O_rec_beta.
        rewrite to_O_natural.
        reflexivity.
      Qed.

      Definition inverse_equiv_O_pushout_to_O_pushl (b : B)
        : equiv_O_pushout^-1 (to O (Pushout (O_functor f) (O_functor g)) (pushl (to O B b)))
          = to O (Pushout f g) (pushl b).
      Proof.
        apply moveR_equiv_V; symmetry; apply equiv_O_pushout_to_O_pushl.
      Qed.

      Definition inverse_equiv_O_pushout_to_O_pushr (c : C)
        : equiv_O_pushout^-1 (to O (Pushout (O_functor f) (O_functor g)) (pushr (to O C c)))
          = to O (Pushout f g) (pushr c).
      Proof.
        apply moveR_equiv_V; symmetry; apply equiv_O_pushout_to_O_pushr.
      Qed.

    End OPushout.

  End Types.

  Section Decidable.

    (** If [Empty] belongs to [O], then [O] preserves decidability. *)
    Global Instance decidable_O `{In O Empty} (A : Type) `{Decidable A}
    : Decidable (O A).
    Proof.
      destruct (dec A) as [y|n].
      - exact (inl (to O A y)).
      - exact (inr (O_rec n)).
    Defined.

    (** Dually, if [O A] is decidable, then [O (Decidable A)]. *)
    Definition O_decidable (A : Type) `{Decidable (O A)}
    : O (Decidable A).
    Proof.
      destruct (dec (O A)) as [y|n].
      - exact (O_functor inl y).
      - refine (O_functor inr _).
        apply to; intros a.
        exact (n (to O A a)).
    Defined.

  End Decidable.

  Section Monad.

    Definition O_monad_mult (A : Type) : O (O A) -> O A
      := O_rec idmap.

    Definition O_monad_mult_natural {A B} (f : A -> B)
    : O_functor f o O_monad_mult A == O_monad_mult B o O_functor (O_functor f).
    Proof.
      apply O_indpaths; intros x; unfold O_monad_mult.
      rewrite (to_O_natural (O_functor f) x).
      rewrite (O_rec_beta idmap x).
      rewrite (O_rec_beta idmap (O_functor f x)).
      reflexivity.
    Qed.

    Definition O_monad_unitlaw1 (A : Type)
    : O_monad_mult A o (to O (O A)) == idmap.
    Proof.
      apply O_indpaths; intros x; unfold O_monad_mult.
      exact (O_rec_beta idmap (to O A x)).
    Defined.

    Definition O_monad_unitlaw2 (A : Type)
    : O_monad_mult A o (O_functor (to O A)) == idmap.
    Proof.
      apply O_indpaths; intros x; unfold O_monad_mult, O_functor.
      repeat rewrite O_rec_beta.
      reflexivity.
    Qed.

    Definition O_monad_mult_assoc (A : Type)
    : O_monad_mult A o O_monad_mult (O A) == O_monad_mult A o O_functor (O_monad_mult A).
    Proof.
      apply O_indpaths; intros x; unfold O_monad_mult, O_functor.
      repeat rewrite O_rec_beta.
      reflexivity.
    Qed.

  End Monad.

  Section StrongMonad.
    Context {fs : Funext}.

    Definition O_monad_strength (A B : Type) : A * O B -> O (A * B)
      := fun aob => O_rec (fun b a => to O (A*B) (a,b)) (snd aob) (fst aob).

    Definition O_monad_strength_natural (A A' B B' : Type) (f : A -> A') (g : B -> B')
    : O_functor (functor_prod f g) o O_monad_strength A B ==
      O_monad_strength A' B' o functor_prod f (O_functor g).
    Proof.
      intros [a ob]. revert a. apply ap10.
      revert ob; apply O_indpaths.
      intros b; simpl.
      apply path_arrow; intros a.
      unfold O_monad_strength, O_functor; simpl.
      repeat rewrite O_rec_beta.
      reflexivity.
    Qed.

    (** The diagrams for strength, see http://en.wikipedia.org/wiki/Strong_monad *)
    Definition O_monad_strength_unitlaw1 (A : Type)
    : O_functor (@snd Unit A) o O_monad_strength Unit A == @snd Unit (O A).
    Proof.
      intros [[] oa]; revert oa.
      apply O_indpaths; intros x; unfold O_monad_strength, O_functor. simpl.
      repeat rewrite O_rec_beta.
      reflexivity.
    Qed.

    Definition O_monad_strength_unitlaw2 (A B : Type)
    : O_monad_strength A B o functor_prod idmap (to O B) == to O (A*B).
    Proof.
      intros [a b].
      unfold O_monad_strength, functor_prod. simpl.
      repeat rewrite O_rec_beta.
      reflexivity.
    Qed.

    Definition O_monad_strength_assoc1 (A B C : Type)
    : O_functor (equiv_prod_assoc A B C)^-1 o O_monad_strength (A*B) C ==
      O_monad_strength A (B*C) o functor_prod idmap (O_monad_strength B C) o (equiv_prod_assoc A B (O C))^-1.
    Proof.
      intros [[a b] oc].
      revert a; apply ap10. revert b; apply ap10.
      revert oc; apply O_indpaths.
      intros c; simpl.
      apply path_arrow; intros b. apply path_arrow; intros a.
      unfold O_monad_strength, O_functor, functor_prod. simpl.
      repeat rewrite O_rec_beta.
      reflexivity.
    Qed.

    Definition O_monad_strength_assoc2 (A B : Type)
    : O_monad_mult (A*B) o O_functor (O_monad_strength A B) o O_monad_strength A (O B) ==
      O_monad_strength A B o functor_prod idmap (O_monad_mult B).
    Proof.
      intros [a oob]. revert a; apply ap10.
      revert oob; apply O_indpaths. apply O_indpaths.
      intros b; simpl. apply path_arrow; intros a.
      unfold O_monad_strength, O_functor, O_monad_mult, functor_prod. simpl.
      repeat (rewrite O_rec_beta; simpl).
      reflexivity.
    Qed.

  End StrongMonad.

End Reflective_Subuniverse.

(** Make the [O_inverts] notation global. *)
Notation O_inverts O f := (IsEquiv (O_functor O f)).

(** ** Modally connected types *)

(** Connectedness of a type, relative to a modality or reflective subuniverse, can be defined in two equivalent ways: quantifying over all maps into modal types, or by considering just the universal case, the modal reflection of the type itself.  The former requires only core Coq, but blows up the size (universe level) of [IsConnected], since it quantifies over types; moreover, it is not even quite correct since (at least with a polymorphic modality) it should really be quantified over all universes.  Thus, we use the latter, although in most examples it requires HITs to define the modal reflection.

Question: is there a definition of connectedness (say, for n-types) that neither blows up the universe level, nor requires HIT's? *)

(** We give annotations to reduce the number of universe parameters. *)
Class IsConnected (O : ReflectiveSubuniverse@{i}) (A : Type@{i})
  := isconnected_contr_O : Contr@{i} (O A).

Global Existing Instance isconnected_contr_O.

Section ConnectedTypes.
  Context (O : ReflectiveSubuniverse).

  (** Being connected is an hprop *)
  Global Instance ishprop_isconnected `{Funext} A
  : IsHProp (IsConnected O A).
  Proof.
    unfold IsConnected; exact _.
  Defined.

  (** Anything equivalent to a connected type is connected. *)
  Definition isconnected_equiv (A : Type) {B : Type} (f : A -> B) `{IsEquiv _ _ f}
  : IsConnected O A -> IsConnected O B.
  Proof.
    intros ?; refine (contr_equiv (O A) (O_functor O f)).
  Defined.

  Definition isconnected_equiv' (A : Type) {B : Type} (f : A <~> B)
  : IsConnected O A -> IsConnected O B
    := isconnected_equiv A f.

  (** Connectedness of a type [A] can equivalently be characterized by the fact that any map to an [O]-type [C] is nullhomotopic.  Here is one direction of that equivalence. *)
  Definition isconnected_elim {A : Type} `{IsConnected O A} (C : Type) `{In O C} (f : A -> C)
  : NullHomotopy f.
  Proof.
    set (ff := @O_rec O _ _ _ _ _ f).
    exists (ff (center _)).
    intros a. symmetry.
    refine (ap ff (contr (to O _ a)) @ _).
    apply O_rec_beta.
  Defined.

  (** For the other direction of the equivalence, it's sufficient to consider the case when [C] is [O A]. *)
  Definition isconnected_from_elim_to_O {A : Type}
  : NullHomotopy (to O A) -> IsConnected O A.
  Proof.
    intros nh.
    exists (nh .1).
    apply O_indpaths; try exact _.
    intros x; symmetry; apply (nh .2).
  Defined.

  (** Now the general case follows. *)
  Definition isconnected_from_elim {A : Type}
  : (forall (C : Type) `{In O C} (f : A -> C), NullHomotopy f)
    -> IsConnected O A.
  Proof.
    intros H.
    exact (isconnected_from_elim_to_O (H (O A) (O_inO A) (to O A))).
  Defined.

  (** Connected types are closed under sigmas. *)
  Global Instance isconnected_sigma {A : Type} {B : A -> Type}
             `{IsConnected O A} `{forall a, IsConnected O (B a)}
  : IsConnected O {a:A & B a}.
  Proof.
    apply isconnected_from_elim; intros C ? f.
    pose (nB := fun a => @isconnected_elim (B a) _ C _ (fun b => f (a;b))).
    pose (nA := isconnected_elim C (fun a => (nB a).1)).
    exists (nA.1); intros [a b].
    exact ((nB a).2 b @ nA.2 a).
  Defined.

  (** Contractible types are connected. *)
  Global Instance isconnected_contr {A : Type} `{Contr A}
    : IsConnected O A.
  Proof.
    apply contr_O_contr; exact _.
  Defined.    

  (** A type which is both connected and truncated is contractible. *)
  Definition contr_trunc_conn {A : Type} `{In O A} `{IsConnected O A}
  : Contr A.
  Proof.
    apply (contr_equiv _ (to O A)^-1).
  Defined.

  (** Any map between connected types is inverted by O. *)
  Global Instance O_inverts_isconnected {A B : Type} (f : A -> B)
             `{IsConnected O A} `{IsConnected O B}
    : O_inverts O f.
  Proof.
    exact _.
  Defined.

  (** Here's another way of stating the universal property for mapping out of connected types into modal ones. *)
  Definition extendable_const_isconnected_inO (n : nat)
             (** Work around https://coq.inria.fr/bugs/show_bug.cgi?id=3811 *)
             (A : Type@{i}) {conn_A : IsConnected@{i} O A}
             (C : Type@{j}) `{In O C}
  : ExtendableAlong n (@const@{i i} A Unit tt) (fun _ => C).
  Proof.
    generalize dependent C;
      simple_induction n n IHn; intros C ?;
      [ exact tt | split ].
    - intros f.
      exists (fun _ : Unit => (isconnected_elim C f).1); intros a.
      symmetry; apply ((isconnected_elim C f).2).
    - intros h k.
      refine (extendable_postcompose' n _ _ _ _ (IHn (h tt = k tt) (inO_paths _ _ _ _))).
      intros []; apply equiv_idmap.
  Defined.

  Definition ooextendable_const_isconnected_inO
             (A : Type@{i}) `{IsConnected@{i} O A}
             (C : Type@{j}) `{In O C}
  : ooExtendableAlong (@const A Unit tt) (fun _ => C)
    := fun n => extendable_const_isconnected_inO n A C.

  Definition isequiv_const_isconnected_inO `{Funext}
             {A : Type} `{IsConnected O A} (C : Type) `{In O C}
  : IsEquiv (@const A C).
  Proof.
    refine (@isequiv_compose _ _ (fun c u => c) _ _ _
              (isequiv_ooextendable (fun _ => C) (@const A Unit tt)
                                    (ooextendable_const_isconnected_inO A C))).
  Defined.

End ConnectedTypes.

(** ** Modally truncated maps *)

(** A map is "in [O]" if each of its fibers is. *)

Class MapIn (O : ReflectiveSubuniverse) {A B : Type} (f : A -> B)
  := inO_hfiber_ino_map : forall (b:B), In O (hfiber f b).

Global Existing Instance inO_hfiber_ino_map.

Section ModalMaps.
  Context (O : ReflectiveSubuniverse).

  (** Any equivalence is modal *)
  Global Instance mapinO_isequiv {A B : Type} (f : A -> B) `{IsEquiv _ _ f}
  : MapIn O f.
  Proof.
    intros b.
    pose (fcontr_isequiv f _ b).
    exact _.
  Defined.

  (** Anything homotopic to a modal map is modal. *)
  Definition mapinO_homotopic {A B : Type} (f : A -> B) {g : A -> B}
             (p : f == g) `{MapIn O _ _ f}
  : MapIn O g.
  Proof.
    intros b.
    refine (inO_equiv_inO (hfiber f b)
                          (equiv_hfiber_homotopic f g p b)).
  Defined.

  (** The projection from a family of modal types is modal. *)
  Global Instance mapinO_pr1 {A : Type} {B : A -> Type}
         `{forall a, In O (B a)}
  : MapIn O (@pr1 A B).
  Proof.
    intros a.
    refine (inO_equiv_inO (B a) (hfiber_fibration a B)).
  Defined.

  (** A slightly specialized result: if [Empty] is modal, then a map with decidable hprop fibers (such as [inl] or [inr]) is modal. *)
  Global Instance mapinO_hfiber_decidable_hprop {A B : Type} (f : A -> B)
         `{In O Empty}
         `{forall b, IsHProp (hfiber f b)}
         `{forall b, Decidable (hfiber f b)}
  : MapIn O f.
  Proof.
    intros b.
    destruct (equiv_decidable_hprop (hfiber f b)) as [e|e].
    - exact (inO_equiv_inO Unit e^-1).
    - exact (inO_equiv_inO Empty e^-1).
  Defined.

  (** Being modal is an hprop *)
  Global Instance ishprop_mapinO `{Funext} {A B : Type} (f : A -> B)
  : IsHProp (MapIn O f).
  Proof.
    apply trunc_forall.
  Defined.

  (** Any map between modal types is modal. *)
  Global Instance mapinO_between_inO {A B : Type} (f : A -> B)
             `{In O A} `{In O B}
  : MapIn O f.
  Proof.
    intros b; exact _.
  Defined.

  (** Modal maps cancel on the left *)
  Definition cancelL_mapinO {A B C : Type} (f : A -> B) (g : B -> C)
  : MapIn O g -> MapIn O (g o f) -> MapIn O f.
  Proof.
    intros ? ? b.
    refine (inO_equiv_inO _ (hfiber_hfiber_compose_map f g b)).
  Defined.

  (** The pullback of a modal map is modal *)
  Global Instance mapinO_pullback {A B C}
         (f : B -> A) (g : C -> A) `{MapIn O _ _ g}
  : MapIn O (f^* g).
  Proof.
    intros b.
    refine (inO_equiv_inO _ (hfiber_pullback_along f g b)^-1).
  Defined.

  Global Instance mapinO_pullback' {A B C}
         (g : C -> A) (f : B -> A) `{MapIn O _ _ f}
  : MapIn O (g^*' f).
  Proof.
    intros c.
    refine (inO_equiv_inO _ (hfiber_pullback_along' g f c)^-1).
  Defined.

  (** [functor_sum] preserves modal maps. *)
  Global Instance mapinO_functor_sum {A A' B B'}
         (f : A -> A') (g : B -> B') `{MapIn O _ _ f} `{MapIn O _ _ g}
  : MapIn O (functor_sum f g).
  Proof.
    intros [a|b].
    - refine (inO_equiv_inO _ (hfiber_functor_sum_l f g a)^-1).
    - refine (inO_equiv_inO _ (hfiber_functor_sum_r f g b)^-1).
  Defined.

  (** So does [unfunctor_sum], if both summands are preserved.  These can't be [Instance]s since they require [Ha] and [Hb] to be supplied. *)
  Definition mapinO_unfunctor_sum_l {A A' B B'}
         (h : A + B -> A' + B')
         (Ha : forall a:A, is_inl (h (inl a)))
         (Hb : forall b:B, is_inr (h (inr b)))
         `{MapIn O _ _ h}
  : MapIn O (unfunctor_sum_l h Ha).
  Proof.
    intros a.
    refine (inO_equiv_inO _ (hfiber_unfunctor_sum_l h Ha Hb a)^-1).
  Defined.

  Definition mapinO_unfunctor_sum_r {A A' B B'}
         (h : A + B -> A' + B')
         (Ha : forall a:A, is_inl (h (inl a)))
         (Hb : forall b:B, is_inr (h (inr b)))
         `{MapIn O _ _ h}
  : MapIn O (unfunctor_sum_r h Hb).
  Proof.
    intros b.
    refine (inO_equiv_inO _ (hfiber_unfunctor_sum_r h Ha Hb b)^-1).
  Defined.

End ModalMaps.

(** ** Modally connected maps *)

(** Connectedness of a map can again be defined in two equivalent ways: by connectedness of its fibers (as types), or by the lifting property/elimination principle against truncated types.  We use the former; the equivalence with the latter is given below in [conn_map_elim], [conn_map_comp], and [conn_map_from_extension_elim]. *)

Class IsConnMap (O : ReflectiveSubuniverse@{i})
      {A : Type@{i}} {B : Type@{i}} (f : A -> B)
  := isconnected_hfiber_conn_map
     (** The extra universe [k] is >= max(i,j). *)
     : forall b:B, IsConnected@{i} O (hfiber@{i i} f b).

Global Existing Instance isconnected_hfiber_conn_map.

Section ConnectedMaps.
  Context `{Univalence} `{Funext}.
  Context (O : ReflectiveSubuniverse).

  (** Any equivalence is connected *)
  Global Instance conn_map_isequiv {A B : Type} (f : A -> B) `{IsEquiv _ _ f}
  : IsConnMap O f.
  Proof.
    intros b.
    pose (fcontr_isequiv f _ b).
    unfold IsConnected; exact _.
  Defined.

  (** Anything homotopic to a connected map is connected. *)
  Definition conn_map_homotopic {A B : Type} (f g : A -> B) (h : f == g)
  : IsConnMap O f -> IsConnMap O g.
  Proof.
    intros ? b.
    exact (isconnected_equiv O (hfiber f b)
                             (equiv_hfiber_homotopic f g h b) _).
  Defined.

  (** The pullback of a connected map is connected *)
  Global Instance conn_map_pullback {A B C}
         (f : B -> A) (g : C -> A) `{IsConnMap O _ _ g}
  : IsConnMap O (f^* g).
  Proof.
    intros b.
    refine (isconnected_equiv _ _ (hfiber_pullback_along f g b)^-1 _).
  Defined.

  Global Instance conn_map_pullback' {A B C}
         (g : C -> A) (f : B -> A) `{IsConnMap O _ _ f}
  : IsConnMap O (g^*' f).
  Proof.
    intros c.
    refine (isconnected_equiv _ _ (hfiber_pullback_along' g f c)^-1 _).
  Defined.

  (** The projection from a family of connected types is connected. *)
  Global Instance conn_map_pr1 {A : Type} {B : A -> Type}
         `{forall a, IsConnected O (B a)}
  : IsConnMap O (@pr1 A B).
  Proof.
    intros a.
    refine (isconnected_equiv O (B a) (hfiber_fibration a B) _).
  Defined.

  (** Being connected is an hprop *)
  Global Instance ishprop_isconnmap `{Funext} {A B : Type} (f : A -> B)
  : IsHProp (IsConnMap O f).
  Proof.
    apply trunc_forall.
  Defined.

  (** n-connected maps are orthogonal to n-truncated maps (i.e. familes of n-truncated types). *)
  Definition conn_map_elim
             {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
             (P : B -> Type) `{forall b:B, In O (P b)}
             (d : forall a:A, P (f a))
  : forall b:B, P b.
  Proof.
    intros b.
    refine (pr1 (isconnected_elim O _ _)).
    intros [a p].
    exact (transport P p (d a)).
  Defined.

  Definition conn_map_comp
             {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
             (P : B -> Type) `{forall b:B, In O (P b)}
             (d : forall a:A, P (f a))
  : forall a:A, conn_map_elim f P d (f a) = d a.
  Proof.
    intros a. unfold conn_map_elim.
    set (fibermap := (fun a0p : hfiber f (f a)
                      => let (a0, p) := a0p in transport P p (d a0))).
    destruct (isconnected_elim O (P (f a)) fibermap) as [x e].
    change (d a) with (fibermap (a;1)).
    apply inverse, e.
  Defined.

  (** A map which is both connected and modal is an equivalence. *)
  Definition isequiv_conn_ino_map {A B : Type} (f : A -> B)
             `{IsConnMap O _ _ f} `{MapIn O _ _ f}
  : IsEquiv f.
  Proof.
    apply isequiv_fcontr. intros b.
    apply (contr_trunc_conn O).
  Defined.

  (** We can re-express this in terms of extensions. *)
  Lemma extension_conn_map_elim
        {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
        (P : B -> Type) `{forall b:B, In O (P b)}
        (d : forall a:A, P (f a))
  : ExtensionAlong f P d.
  Proof.
    exists (conn_map_elim f P d).
    apply conn_map_comp.
  Defined.

  Definition extendable_conn_map_inO (n : nat)
             {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
             (P : B -> Type) `{forall b:B, In O (P b)}
  : ExtendableAlong n f P.
  Proof.
    generalize dependent P.
    simple_induction n n IHn; intros P ?; [ exact tt | split ].
    - intros d; apply extension_conn_map_elim; exact _.
    - intros h k; apply IHn; exact _.
  Defined.

  Definition ooextendable_conn_map_inO
             {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
             (P : B -> Type) `{forall b:B, In O (P b)}
  : ooExtendableAlong f P
    := fun n => extendable_conn_map_inO n f P.

  Lemma allpath_extension_conn_map
        {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
        (P : B -> Type) `{forall b:B, In O (P b)}
        (d : forall a:A, P (f a))
        (e e' : ExtensionAlong f P d)
  : e = e'.
  Proof.
    apply path_extension.
    refine (extension_conn_map_elim _ _ _).
  Defined.

  (** It follows that [conn_map_elim] is actually an equivalence. *)
  Theorem isequiv_o_conn_map 
          {A B : Type} (f : A -> B) `{IsConnMap O _ _ f}
          (P : B -> Type) `{forall b:B, In O (P b)}
  : IsEquiv (fun (g : forall b:B, P b) => g oD f).
  Proof.
    apply isequiv_fcontr; intros d.
    apply contr_inhabited_hprop.
    - refine (@trunc_equiv' {g : forall b, P b & g oD f == d} _ _ _ _).
      { refine (equiv_functor_sigma_id _); intros g.
        apply equiv_path_forall. }
      apply hprop_allpath. intros g h.
      exact (allpath_extension_conn_map f P d g h).
    - exists (conn_map_elim f P d).
      apply path_forall; intros x; apply conn_map_comp.
  Defined.

  (** Conversely, if a map satisfies this elimination principle (expressed via extensions), then it is connected.  This completes the proof of Lemma 7.5.7 from the book. *)
  Lemma conn_map_from_extension_elim {A B : Type} (f : A -> B)
  : (forall (P : B -> Type) {P_inO : forall b:B, In O (P b)}
            (d : forall a:A, P (f a)),
       ExtensionAlong f P d)
    -> IsConnMap O f.
  Proof.
    intros Hf b. apply isconnected_from_elim_to_O.
    assert (e := Hf (fun b => O (hfiber f b)) _ (fun a => to O _ (a;1))).
    exists (e.1 b).
    intros [a p]. destruct p.
    symmetry; apply (e.2).
  Defined.

  (** Lemma 7.5.6: Connected maps compose and cancel on the right. *)
  Global Instance conn_map_compose {A B C : Type} (f : A -> B) (g : B -> C)
         `{IsConnMap O _ _ f} `{IsConnMap O _ _ g}
  : IsConnMap O (g o f).
  Proof.
    apply conn_map_from_extension_elim; intros P ? d.
    exists (conn_map_elim g P (conn_map_elim f (P o g) d)); intros a.
    exact (conn_map_comp g P _ _ @ conn_map_comp f (P o g) d a).
  Defined.      

  Definition cancelR_conn_map {A B C : Type} (f : A -> B) (g : B -> C)
         `{IsConnMap O _ _ f} `{IsConnMap O _ _ (g o f)}
  :  IsConnMap O g.
  Proof.
    apply conn_map_from_extension_elim; intros P ? d.
    exists (conn_map_elim (g o f) P (d oD f)); intros b.
    pattern b; refine (conn_map_elim f _ _ b); intros a.
    exact (conn_map_comp (g o f) P (d oD f) a).
  Defined.

  (** Connected maps also cancel with equivalences on the other side. *)
  Definition cancelR_isequiv_conn_map {A B C : Type} (f : A -> B) (g : B -> C)
         `{IsEquiv _ _ g} `{IsConnMap O _ _ (g o f)}
    : IsConnMap O f.
  Proof.
    intros b.
    srefine (isconnected_equiv' O (hfiber (g o f) (g b)) _ _).
    exact (equiv_inverse (equiv_functor_sigma_id (fun a => equiv_ap g (f a) b))).
  Defined.

  Definition cancelR_equiv_conn_map {A B C : Type} (f : A -> B) (g : B <~> C)
         `{IsConnMap O _ _ (g o f)}
    : IsConnMap O f
    := cancelR_isequiv_conn_map f g.

  (** The constant map to [Unit] is connected just when its domain is. *)
  Definition isconnected_conn_map_to_unit {A : Type}
             `{IsConnMap O _ _ (@const A Unit tt)}
  : IsConnected O A.
  Proof.
    refine (isconnected_equiv O (hfiber (@const A Unit tt) tt)
              (equiv_sigma_contr (fun a:A => const tt a = tt)) _).
  Defined.

  Hint Immediate isconnected_conn_map_to_unit : typeclass_instances.

  Global Instance conn_map_to_unit_isconnected {A : Type}
         `{IsConnected O A}
  : IsConnMap O (@const A Unit tt).
  Proof.
    intros u.
    refine (isconnected_equiv O A
              (equiv_sigma_contr (fun a:A => const tt a = u))^-1 _).
  Defined.

  (* Lemma 7.5.10: A map to a type in [O] exhibits its codomain as the [O]-reflection of its domain if it is [O]-connected.  (The converse is true if and only if [O] is a modality.) *)
  Definition isequiv_O_rec_conn_map {A B : Type} `{In O B}
             (f : A -> B) `{IsConnMap O _ _ f}
  : IsEquiv (O_rec (O := O) f).
  Proof.
    refine (isequiv_adjointify _ (conn_map_elim f (fun _ => O A) (to O A)) _ _).
    - intros x. pattern x.
      refine (conn_map_elim f _ _ x); intros a.
      exact (ap (O_rec f)
                (conn_map_comp f (fun _ => O A) (to O A) a)
                @ O_rec_beta f a).
    - apply O_indpaths; intros a; simpl.
      refine (ap _ (O_rec_beta f a) @ _).
      refine (conn_map_comp f (fun _ => O A) (to O A) a).
  Defined.

  (** Lemma 7.5.12 *)
  Section ConnMapFunctorSigma.

    Context {A B : Type} {P : A -> Type} {Q : B -> Type}
            (f : A -> B) (g : forall a, P a -> Q (f a))
            `{forall a, IsConnMap O (g a)}.

    Definition equiv_O_hfiber_functor_sigma (b:B) (v:Q b)
    : O (hfiber (functor_sigma f g) (b;v)) <~> O (hfiber f b).
    Proof.
      equiv_via (O {w : hfiber f b & hfiber (g w.1) ((w.2)^ # v)}).
      { apply equiv_O_functor, hfiber_functor_sigma. }
      equiv_via (O {w : hfiber f b & O (hfiber (g w.1) ((w.2)^ # v))}).
      { symmetry; apply equiv_O_sigma_O. }
      apply equiv_O_functor.
      apply equiv_sigma_contr; intros [a p]; simpl; exact _.
    Defined.

    Global Instance conn_map_functor_sigma `{IsConnMap O _ _ f}
    : IsConnMap O (functor_sigma f g).
    Proof.
      intros [b v].
      refine (contr_equiv' _ (equiv_inverse (equiv_O_hfiber_functor_sigma b v))).
    Defined.

    Definition conn_map_base_inhabited (inh : forall b, Q b)
               `{IsConnMap O _ _ (functor_sigma f g)}
    : IsConnMap O f.
    Proof.
      intros b.
      refine (contr_equiv _ (equiv_O_hfiber_functor_sigma b (inh b))).
    Defined.

  End ConnMapFunctorSigma.

  (** Lemma 7.5.13.  The "if" direction is a special case of [conn_map_functor_sigma], so we prove only the "only if" direction. *)
  Definition conn_map_fiber
             {A : Type} {P Q : A -> Type} (f : forall a, P a -> Q a)
             `{IsConnMap O _ _ (functor_sigma idmap f)}
  : forall a, IsConnMap O (f a).
  Proof.
    intros a q.
    refine (isconnected_equiv' O (hfiber (functor_sigma idmap f) (a;q)) _ _).
    exact (hfiber_functor_sigma_idmap P Q f a q).
  Defined.

  (** Lemma 7.5.14: Connected maps are inverted by [O]. *)
  Global Instance O_inverts_conn_map {A B : Type} (f : A -> B)
         `{IsConnMap O _ _ f}
  : IsEquiv (O_functor O f).
  Proof.
    simple refine (isequiv_adjointify _ _ _ _).
    - apply O_rec; intros y.
      exact (O_functor O pr1 (center (O (hfiber f y)))).
    - unfold Sect; apply O_indpaths; try exact _; intros b.
      refine (ap (O_functor O f) (O_rec_beta _ b) @ _).
      refine ((O_functor_compose _ _ _ _)^ @ _).
      set (x := (center (O (hfiber f b)))).
      clearbody x; revert x; apply O_indpaths; try exact _; intros [a p].
      refine (O_rec_beta (to O B o (f o pr1)) (a;p) @ _).
      exact (ap (to O B) p).
    - unfold Sect; apply O_indpaths; try exact _; intros a.
      refine (ap (O_rec _) (to_O_natural O f a) @ _).
      refine (O_rec_beta _ _ @ _).
      transitivity (O_functor O pr1 (to O (hfiber f (f a)) (a;1))).
      + apply ap, contr.
      + refine (to_O_natural _ _ _).
  Defined.

  (** As a consequence, connected maps between modal types are equivalences. *)
  Definition isequiv_conn_map_ino {A B : Type} (f : A -> B)
         `{In O A} `{In O B} `{IsConnMap O _ _ f}
    : IsEquiv f
    := isequiv_commsq' f (O_functor O f) (to O A) (to O B) (to_O_natural O f).

  (** Connectedness is preserved by [O_functor]. *)
  Global Instance conn_map_O_functor {A B} (f : A -> B) `{IsConnMap O _ _ f}
    : IsConnMap O (O_functor O f).
  Proof.
    unfold O_functor.
    rapply conn_map_compose.
  Defined.

End ConnectedMaps.

(** ** Containment of (reflective) subuniverses *)

(** One subuniverse is contained in another if every [O1]-modal type is [O2]-modal.  We define this parametrized by three universes: [O1] and [O2] are reflective subuniverses of [Type@{i1}] and [Type@{i2}] respectively, and the relation says that all types in [Type@{j}] that [O1]-modal are also [O2]-modal.  This implies [j <= i1] and [j <= i2], of course.  The most common application is when [i1 = i2 = j], but it's sometimes useful to talk about a subuniverse of a larger universe agreeing with a subuniverse of a smaller universe on the smaller universe.  *)
Class O_leq@{i1 i2 j} (O1 : Subuniverse@{i1}) (O2 : Subuniverse@{i2})
  := inO_leq : forall (A : Type@{j}), In O1 A -> In O2 A.

Arguments inO_leq O1 O2 {_} A _.

Declare Scope subuniverse_scope.
Notation "O1 <= O2" := (O_leq O1 O2) : subuniverse_scope.
Open Scope subuniverse_scope.

Global Instance reflexive_O_leq : Reflexive O_leq | 10.
Proof.
  intros O A ?; assumption.
Defined.

Global Instance transitive_O_leq : Transitive O_leq | 10.
Proof.
  intros O1 O2 O3 O12 O23 A ?.
  rapply (@inO_leq O2 O3).
  rapply (@inO_leq O1 O2).
Defined.

(** This implies that every [O2]-connected type is [O1]-connected, and similarly for maps and equivalences.  We give universe annotations so that [O1] and [O2] don't have to be on the same universe, but we do have to have [i1 <= i2] for this statement.  When [i2 <= i1] it seems that the statement might not be true unless the RSU on the larger universe is accessibly extended from the smaller one; see [Localization.v].  *)
Definition isconnected_O_leq@{i1 i2}
           (O1 : ReflectiveSubuniverse@{i1}) (O2 : ReflectiveSubuniverse@{i2}) `{O_leq@{i1 i2 i1} O1 O2}
           (A : Type@{i1}) `{IsConnected O2 A}
  : IsConnected O1 A.
Proof.
  apply isconnected_from_elim.
  intros C C1 f.
  apply (isconnected_elim O2); srapply inO_leq; exact _.
Defined.

(** This one has the same universe constraint [i1 <= i2]. *)
Definition conn_map_O_leq@{i1 i2}
           (O1 : ReflectiveSubuniverse@{i1}) (O2 : ReflectiveSubuniverse@{i2}) `{O_leq@{i1 i2 i1} O1 O2}
           {A B : Type@{i1}} (f : A -> B) `{IsConnMap O2 A B f}
  : IsConnMap O1 f.
Proof.
  (** We could prove this by applying [isconnected_O_leq] fiberwise, but unless we were very careful that would collapse the two universes [i1] and [i2].  So instead we just give an analogous direct proof. *)
  apply conn_map_from_extension_elim.
  intros P P_inO g.
  rapply (extension_conn_map_elim O2).
  intros b; rapply (inO_leq O1).
Defined.

(** This is Lemma 2.12(i) in CORS, again with the same universe constraint [i1 <= i2]. *)
Definition O_inverts_O_leq@{i1 i2}
           (O1 : ReflectiveSubuniverse@{i1}) (O2 : ReflectiveSubuniverse@{i2}) `{O_leq@{i1 i2 i1} O1 O2}
           {A B : Type@{i1}} (f : A -> B) `{O_inverts O2 f}
  : O_inverts O1 f.
Proof.
  apply O_inverts_from_extendable@{i1 i1 i1 i1 i1}; intros Z Z_inO.
  pose (inO_leq O1 O2 Z _).
  apply (lift_extendablealong@{i1 i1 i1 i1 i1 i1 i2 i1 i1 i2 i1}).
  apply (ooextendable_O_inverts O2); exact _.
Defined.


(** ** Equality of (reflective) subuniverses *)

(** Two subuniverses are the same if they have the same modal types.  The universe parameters are the same as for [O_leq]: [O1] and [O2] are reflective subuniverses of [Type@{i1}] and [Type@{i2}], and the relation says that they agree when restricted to [Type@{j}], where [j <= i1] and [j <= i2]. *)
Class O_eq@{i1 i2 j} (O1 : Subuniverse@{i1}) (O2 : Subuniverse@{i2}) :=
{
  O_eq_l : O_leq@{i1 i2 j} O1 O2 ;
  O_eq_r : O_leq@{i2 i1 j} O2 O1 ;
}.

Global Existing Instances O_eq_l O_eq_r.

Notation "O1 <=> O2" := (O_eq O1 O2) (at level 70) : subuniverse_scope.

Definition issig_O_eq O1 O2 : _ <~> O_eq O1 O2 := ltac:(issig).

Global Instance reflexive_O_eq : Reflexive O_eq | 10.
Proof.
  intros; split; reflexivity.
Defined.

Global Instance transitive_O_eq : Transitive O_eq | 10.
Proof.
  intros O1 O2 O3; split; refine (transitivity (y := O2) _ _).
Defined.

Global Instance symmetric_O_eq : Symmetric O_eq | 10.
Proof.
  intros O1 O2 [? ?]; split; assumption.
Defined.

Definition issig_subuniverse : _ <~> Subuniverse := ltac:(issig).

Definition equiv_path_subuniverse `{Univalence} (O1 O2 : Subuniverse)
  : (O1 <=> O2) <~> (O1 = O2).
Proof.
  refine (_ oE (issig_O_eq O1 O2)^-1).
  revert O1 O2; refine (equiv_path_along_equiv issig_subuniverse _).
  cbn; intros O1 O2.
  refine (equiv_path_sigma_hprop O1 O2 oE _).
  destruct O1 as [O1 [O1h ?]]; destruct O2 as [O2 [O2h ?]]; cbn.
  refine (equiv_path_arrow _ _ oE _).
  srapply (equiv_iff_hprop).
  - srapply trunc_sigma; unfold O_leq; exact _.
  - intros [h k] A; specialize (h A); specialize (k A); cbn in *.
    apply path_universe_uncurried, equiv_iff_hprop; assumption.
  - intros h; split; intros A e; specialize (h A); cbn in *.
    1:rewrite <- h.
    2:rewrite h.
    all:exact e.
Defined.

(** It should also be true that if [O1] and [O2] are reflective subuniverses, then [O1 <=> O2] is equivalent to [O1 = O2 :> ReflectiveSubuniverse].  Probably [contr_typeof_O_unit] should be useful in proving that. *)

(** Reflections into one subuniverse are also reflections into an equal one.  Unfortunately these almost certainly can't be [Instance]s for fear of infinite loops, since [<=>] is reflexive. *)
Definition prereflects_O_leq
           (O1 O2 : Subuniverse) `{O1 <= O2}
           (A : Type) `{PreReflects O1 A}
  : PreReflects O2 A.
Proof.
  unshelve econstructor.
  - exact (O_reflector O1 A).
  - rapply (inO_leq O1 O2).
  - exact (to O1 A).
Defined.

Definition reflects_O_eq
           (O1 O2 : Subuniverse) `{O1 <=> O2}
           (A : Type) `{Reflects O1 A}
  : @Reflects O2 A (prereflects_O_leq O1 O2 A).
Proof.
  constructor; intros B B_inO2.
  pose proof (inO_leq O2 O1 _ B_inO2).
  apply (extendable_to_O O1).
Defined.


(** ** Separated subuniverses *)

(** For any subuniverse [O], a type is [O]-separated iff all its identity types are [O]-modal.  We will study these further in [Separated.v], but we put the definition here because it's needed in [Descent.v]. *)
Definition Sep (O : Subuniverse) : Subuniverse.
Proof.
  unshelve econstructor.
  - intros A; exact (forall (x y:A), In O (x = y)).
  - exact _.
  - intros T U ? f ? x y; cbn in *.
    refine (inO_equiv_inO' _ (equiv_ap f^-1 x y)^-1).
Defined.

Global Instance inO_paths_SepO (O : Subuniverse)
       {A : Type} {A_inO : In (Sep O) A} (x y : A)
  : In O (x = y)
  := A_inO x y.

Global Instance O_leq_SepO (O : ReflectiveSubuniverse)
  : O <= Sep O.
Proof.
  intros A A_inO x y; exact _.
Defined.
